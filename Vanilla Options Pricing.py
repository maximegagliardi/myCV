# -*- coding: utf-8 -*-
"""
Created on Mon Apr 28 21:27:29 2025

@author: maxgu
"""

import numpy as np
import pandas as pd
import scipy.stats
from datetime import datetime
import matplotlib.pyplot as plt

#The code is designed to be fully interactive, which means that all you have to do is enter the parameters of the option you want to price once the code has been executed, to obtain the option price, as well as the payoff graph.

def get_input(prompt, cast_func, error_msg):
    while True:
        try:
            return cast_func(input(prompt))
        except Exception:
            print(error_msg)

S0 = get_input("Entrez S0 : ", float, "Veuillez entrer un nombre pour S0")
K = get_input("Entrez K : ", float, "Veuillez entrer un nombre pour K")
rf = get_input("Entrez rf : ", float, "Veuillez entrer un nombre pour rf.")
q = get_input("Entrez q, le taux de dividende : ", float, "Veuillez entrer un nombre pour q.")
vol = get_input("Entrez la valeur de la vol : ", float, "Veuillez entrer un nombre pour la vol.")

purchase_date = get_input("Entrez la date d'achat (YYYY-MM-DD) : ", lambda x: datetime.strptime(x, "%Y-%m-%d"), "Le format de la date doit être YYYY-MM-DD.")
maturity_date = get_input("Entrez la date de maturité (YYYY-MM-DD) : ", lambda x: datetime.strptime(x, "%Y-%m-%d"), "Le format de la date doit être YYYY-MM-DD.")

"""

S0 = 100
K = 100
rf = 0.024
q = 0.01
vol = 1.2
purchase_date = datetime.strptime('2025-04-28', "%Y-%m-%d")
maturity_date = datetime.strptime('2025-07-28', "%Y-%m-%d")
"""

def d1d2_calc(S0, K, rf, vol, purchase_date, maturity_date):
    #purchase_date = datetime.strptime(purchase_date, "%Y-%m-%d")
    #maturity_date = datetime.strptime(maturity_date, "%Y-%m-%d")
    t = (maturity_date - purchase_date).days / 365
    d1 = (np.log(S0 / K) + (rf - q + vol ** 2 / 2) * t) / (vol * np.sqrt(t)) 
    d2 = d1 - vol * np.sqrt(t)
    return d1, d2, t

d1, d2, t = d1d2_calc(S0, K, rf, vol, purchase_date, maturity_date)

#print(d1)
#print(d2)
#print(t)

N = scipy.stats.norm.cdf
N_deriv = scipy.stats.norm.pdf

def call_pricing():
    c = S0 * np.exp(-q*t) * N(d1) - K * np.exp(-rf * t) * N(d2)
    return np.round(c, 2)

c = call_pricing()
#print(c)
    
def put_pricing():
    p = K * np.exp(-rf * t) * N(-d2) - S0 * np.exp(-q*t) * N(-d1)
    return np.round(p, 2)

p = put_pricing()
#print(p)


def plot_payoff(payoff_func, lab, col='r', S0=100):
    x_range = (S0 * 0.5, S0 * 1.5)
    x = np.linspace(x_range[0], x_range[1], 200)
    y = payoff_func(x)
    fig, ax = plt.subplots(figsize=(8,6))
    ax.spines['bottom'].set_position('zero') #posne l'axe des x sur y=0
    ax.plot(x, y,label=lab, color=col)
    plt.xlabel('S0 Price')
    plt.ylabel('Profit & Loss')
    plt.title('P&L en fonction du spot')
    plt.legend()
    plt.grid(True)
    plt.show()
    
    
def build_option_payoff(option_type, pos, K, premium):
    mult = 1 if pos == 'long' else -1
    if option_type == 'call':
        return lambda S: mult * (np.maximum(S - K, 0) - premium)
    elif option_type == 'put':
        return lambda S: mult * (np.maximum(K - S, 0) - premium)
    else:
        raise ValueError("L'option doit être 'call' ou 'put'.")

option_type = input("Entrez le type d'option (call/put) : ").lower()
while option_type not in ['call', 'put']:
    option_type = input("Erreur ! Entrez le type d'option ('call' ou 'put') : ").lower()

pos = input("Entrez la position (long/short) : ").lower()
while pos not in ['long', 'short']:
    pos = input("Erreur ! Entrez la position ('long' ou 'short') : ").lower()

if option_type == 'call':
    delta = np.exp(-q*t) * N(d1)
    theta = -S0*vol*np.exp(-q*t)*N_deriv(d1)/(2*np.sqrt(t)) - rf*K*np.exp(-rf*t)*N(d2) + q*S0*np.exp(-q*t)*N(d1)
    rho = K*t*np.exp(-rf*t)*N(d2)
    epsilon = - t*S0*np.exp(-q*t)*N(d1) - S0*np.exp(-q*t)*np.sqrt(t)*N_deriv(d1)/vol + np.sqrt(t)*K*np.exp(-rf*t)*N_deriv(d2)/vol
    premium = c
    col = 'r'
    print('Prix du call = ', c)
else:
    delta = np.exp(-q*t) * (N(d1)-1)
    theta = -S0*vol*np.exp(-q*t)*N_deriv(d1)/(2*np.sqrt(t)) + rf*K*np.exp(-rf*t)*N(-d2) - q*S0*np.exp(-q*t)*N(-d1)
    rho = - K*t*np.exp(-rf*t)*N(d2)
    epsilon = np.sqrt(t)*K*np.exp(-rf*t)*N_deriv(-d2)/vol + t*S0*np.exp(-q*t)*N(-d1) - S0*np.exp(-q*t)*np.sqrt(t)*N_deriv(-d1)/vol
    premium = p
    col = 'b'
    print('Prix du put = ', p)

vega = S0*np.sqrt(t)*N_deriv(d1)*np.exp(-q*t)
gamma = N_deriv(d1)*np.exp(-q*t)/(S0*vol*np.sqrt(t))

payoff_func = build_option_payoff(option_type, pos, K, premium)
lab = "{} {}".format(pos.capitalize(), option_type.capitalize())

data = {
    'Grecques': ['Delta', 'Gamma', 'Vega', 'Rho', 'Theta', 'Epsilon'],
    'Valeur': [
        np.round(delta, 4), #variation du prix pour une augmentation de 1 unité du sous jacent
        np.round(gamma, 4), #variation du delta pour une augmentation de 1 unité du sous jacent
        np.round(vega/100, 4), #variation du prix pour une augmentation de 1% de la vol
        np.round(rho/100, 4), #variation du prix pour une augmentation de 1% de rf
        np.round(theta/365, 4), #le theta s'interprète ici comme la variation du prix pour chaque jour qui passe
        np.round(epsilon/100, 4) #variation du prix pour une augmentation de 1% de q
    ]
}

#ces modifications ci-dessus ont pour but de faciliter la lecture et l'interprétation des grecques

df = pd.DataFrame(data)
print(df)

plot_payoff(payoff_func, lab, col, S0)



