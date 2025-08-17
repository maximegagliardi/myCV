#!/usr/bin/env python
# coding: utf-8

# In[15]:

#premiere version
##Autocall blackscholes simulation

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
 
 # Parameters
VIS = 16.25
S0 =  16.25 
r = 0.04
q = 0.02 #Dividend yield

sigma = 0.2
T = (pd.to_datetime('2025-06-17')- pd.to_datetime('2023-06-17')).days / 365.25 # Time to maturity in years
m = 5 # Number of oqservation dates remaining
barriere_autocall = 16.25 # 100%*VIS
barriere_coupon = 11.375 # Coupon barrier (and Capital Protection Barrier, 70% of VIS)
I0 = 16.25 # Initial investment amount
Qj = 0.025*I0 # Payoff if the coupon barrier is hit (Coupon amount)
N = 10000 # Number of simulations

# Fixing dates (semi-annual periods)
dates_obs = pd.date_range(start='2023-06-17', end='2025-06-17', freq='6M')
dates_obs_list = dates_obs.strftime('%d/%m/%Y').tolist()
 
# Function to simulate the path of the underlying asset
def simulation_traj(S0, r, q, sigma, T, m, N):
    dt = T / m
    S = np.zeros((m + 1, N))
    S[0] = S0
    for t in range(1, m + 1):
        Z = np.random.standard_normal(N)
        S[t] = S[t- 1] * np.exp((r- q- 0.5 * sigma**2) * dt + sigma * np.sqrt(dt) * Z)
    return S

# Simulate traj
np.random.seed(42) # For reproducibility
traj = simulation_traj(S0, r, q, sigma, T, m, N)

# Initialize variables to store results
coupons_payes = np.zeros(N)
autocalled = np.zeros(N, dtype=bool)

# Evaluate traj to determine coupon payments and autocall events
for i in range(N):
    for t in range(1, m + 1):
        if traj[t, i] >= barriere_autocall:
            autocalled[i] = True
            coupons_payes[i] += Qj
            break
        elif traj[t, i] >= barriere_coupon:
            coupons_payes[i] += Qj
    
# Calculate the final payoff considering the capital protection barrier
IF = np.where(traj[-1] < barriere_coupon, I0 * (traj[-1] / VIS), I0) #IF pour investissement final
# Total value of the product at maturity
val_totale = IF + coupons_payes
# Discount to present value
valeur_actuelle = val_totale * np.exp(-r * T) 
valeur_attendue = round(np.mean(valeur_actuelle), 2)
    
print(f"Expected Present Value of the Autocall: {valeur_attendue:.2f}")
 # Print fixing dates for reference
print("Fixing Dates:", ", ".join(dates_obs_list))
#%%

# Suite, deuxieme version avec les grecques à la suite

# In[15bis-modified]:

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

r0 = 0.04          
q0 = 0.02 #Rendement du dividende
sigma0 = 0.2       
T = (pd.to_datetime('2025-06-17')- pd.to_datetime('2023-06-17')).days / 365.25
m = 5 #Nombre de dates d'observation semi-annuelles restantes
N = 10000 #Nombre de simulations

VIS = 16.25
barriere_autocall = 16.25 #100%*VIS
barriere_coupon = 11.375 #Barrière de coupon / protection du capital (70%)
I0 = 16.25 # Montant investi initialement
C = 0.025 * I0  # Montant du coupon

# La fonction de simulation GBM

def simulation_traj(S0, r, q, sigma, T, m, N):
    dt = T / m
    S = np.zeros((m + 1, N))
    S[0] = S0
    for t in range(1, m + 1):
        Z = np.random.standard_normal(N)
        S[t] = S[t - 1] * np.exp((r - q - 0.5 * sigma**2) * dt + sigma * np.sqrt(dt) * Z)
    return S

# Fonction de pricing de l'autocall en fonction d'un S0 initial variant
# Ici, même si S0 change, les paramètres d'émission restent fixes.

def autocall_price_for_S0_fixed(S0, r=r0, q=q0, sigma=sigma0, T=T, m=m, N=N):
    # Paramètres fixes d'émission (non scalés avec S0)
    VIS_local = VIS                    
    barriere_autocall_local = barriere_autocall
    barriere_coupon_local = barriere_coupon       
    I0_local = I0  
    C_local = C
    np.random.seed(42)  # Pour la reproductibilité
    # Ici, on démarre la simulation avec S0 variable
    traj = simulation_traj(S0, r, q, sigma, T, m, N)
    coupons_payes = np.zeros(N)
    for i in range(N):
        for t in range(1, m + 1):
            if traj[t, i] >= barriere_autocall_local:
                coupons_payes[i] += C_local
                break   # Dès l'autocall, on arrête d'évaluer la trajectoire
            elif traj[t, i] >= barriere_coupon_local:
                coupons_payes[i] += C_local
    # Calcul du remboursement final avec protection du capital
    IF = np.where(traj[-1] < barriere_coupon_local, I0_local * (traj[-1] / VIS_local), I0_local)
    val_totale = IF + coupons_payes
    valeur_actuelle = np.exp(-r * T) * val_totale
    return round(np.mean(valeur_actuelle), 2)

print("prix de l'autocall : ", autocall_price_for_S0_fixed(VIS))

#%%

# Analyse de sensibilité par rapport à S0 (delta)
# On fait varier la valeur initiale du sous-jacent sur une grille

S0_range = np.linspace(0, 2*16.25, 50)
prices = np.array([autocall_price_for_S0_fixed(s0) for s0 in S0_range])

# Calcul du Delta à l'aide du gradient
delta = np.gradient(prices, S0_range)

plt.figure(figsize=(12, 5))

# Graphique du prix de l'autocall en fonction de S
plt.plot(S0_range, prices, marker='', linestyle='-', color='blue', lw=2)
plt.axvline(x=VIS, color='black', linestyle='--', label='S0')
plt.axvline(x=barriere_coupon, color='grey', linestyle='--', label='Barrière de protection/coupon')
plt.axhline(y=0, color='k', linestyle ='-', lw=1)
plt.xlabel('S0 (Valeur initiale du sous-jacent)')
plt.ylabel('Prix de l\'autocall')
plt.title('Prix de l\'autocall en fonction de la valeur du sous-jacent')
plt.legend()
plt.grid(True)

plt.figure(figsize=(12, 5))
# Graphique du Delta en fonction de S
plt.plot(S0_range, delta, marker='', linestyle='-', color='red', label='Delta', lw=2)
plt.axvline(x=VIS, color='black', linestyle='--', label='Barrière d\'autocall')
plt.axvline(x=barriere_coupon, color='grey', linestyle='--', label='Barrière de protection/coupon')
plt.axhline(y=0, color='k', linestyle ='-', lw=1)
plt.xlabel('S0 (VIS)')
plt.ylabel('Delta')
plt.title('Delta de l\'autocall')
plt.legend()
plt.grid(True)

plt.show()

#%%

# Calcul du Gamma
gamma = np.gradient(delta, S0_range)

# Affichage du graphique du Gamma en fonction de S0
plt.figure(figsize=(12, 5))
plt.plot(S0_range, gamma, marker='', linestyle='-', color='orange', label='Gamma', lw=2)
plt.axvline(x=VIS, color='black', linestyle='--', label='Barrière d\'autocall')
plt.axvline(x=barriere_coupon, color='grey', linestyle='--', label='Barrière de protection/coupon')
plt.axhline(y=0, color='k', linestyle ='-', lw=1)
plt.xlabel('S0 (Valeur initiale du sous-jacent)')
plt.ylabel('Gamma')
plt.title('Gamma de l\'autocall')
plt.legend()
plt.grid(True)

plt.show()

#%%

# Calcul du Vega en fonction de S0

def autocall_vega(S0, sigma_ref, dsigma=0.05, r=r0, q=q0, T=T, m=m, N=N):
    price_plus = autocall_price_for_S0_fixed(S0, sigma = sigma0 + dsigma, r=r0, q=q0, T=T, m=m, N=N)
    price_minus = autocall_price_for_S0_fixed(S0, sigma = sigma0 - dsigma, r=r0, q=q0, T=T, m=m, N=N)
    return (price_plus - price_minus) / (2 * dsigma)

# Utilisation de la fonction ci-dessus pour calculer le vega en fonction de S0

# On définit une grille de valeurs pour S0
S0_range_vega = np.linspace(0, 3*16.25, 50)
# ici la volatilité de référence est 0.2

# Calcul du vega pour chaque valeur de S0 de la grille
vega_S0 = np.array([autocall_vega(s0, sigma_ref=sigma0, dsigma=0.05) for s0 in S0_range_vega])

plt.figure(figsize=(12, 5))
plt.plot(S0_range_vega, vega_S0, marker='', linestyle='-', color='magenta', label='Vega', lw=2)
plt.axvline(x=VIS, color='black', linestyle='--', label='VIS')
plt.axvline(x=barriere_coupon, color='grey', linestyle='--', label='Barrière de protection/coupon')
plt.axhline(y=0, color='k', linestyle ='-', lw=1)
plt.xlabel('S0 (Valeur initiale du sous-jacent)')
plt.ylabel('Vega')
plt.title("Vega de l'autocall en fonction de S0")
plt.legend()
plt.grid(True)
plt.show()

#%%

#Theta

# Fonction pour calculer le theta de l'autocall (sensibilité du prix par rapport à T)
def autocall_theta(S0, T_ref, dT=1, r=r0, q=q0, sigma=sigma0, m=m, N=N):
    price_plus = autocall_price_for_S0_fixed(S0, r=r0, q=q0, sigma=sigma0, T=T + dT, m=m, N=N)
    price_minus = autocall_price_for_S0_fixed(S0, r=r0, q=q0, sigma=sigma0, T=T - dT, m=m, N=N)
    theta_val = (price_plus - price_minus) / (2 * dT)
    return theta_val

theta_S0 = np.array([autocall_theta(s, T_ref=T) for s in S0_range])

plt.figure(figsize=(12, 5))
plt.plot(S0_range, theta_S0, marker='', linestyle='-', color='brown', label='Theta')
plt.axvline(x=VIS, color='black', linestyle='--', label='VIS')
plt.axvline(x=barriere_coupon, color='grey', linestyle='--', label='Barrière de protection/coupon')
plt.axhline(y=0, color='k', linestyle ='-', lw=1)
plt.xlabel('S0')
plt.ylabel('Theta')
plt.title("Theta de l'autocall en fonction de S0")
plt.legend()
plt.grid(True)
plt.show()

#%%

# Fonction pour calculer le Rho de l'autocall (sensibilité du prix par rapport à r)
def autocall_rho(S0, r_ref, dr=0.05, q=q0, sigma=sigma0, T=T, m=m, N=N):
    price_plus = autocall_price_for_S0_fixed(S0, r=r0 + dr, q=q0, sigma=sigma0, T=T, m=m, N=N)
    price_minus = autocall_price_for_S0_fixed(S0, r=r0 - dr, q=q0, sigma=sigma0, T=T, m=m, N=N)
    return (price_plus - price_minus) / (2 * dr)

rho_S0 = np.array([autocall_rho(s0, r_ref=r0) for s0 in S0_range])

plt.figure(figsize=(12, 5))
plt.plot(S0_range, rho_S0, marker='', linestyle='-', color='blue', label='Rho')
plt.axvline(x=VIS, color='black', linestyle='--', label='VIS')
plt.axvline(x=barriere_coupon, color='grey', linestyle='--', label='Barrière de protection/coupon')
plt.axhline(y=0, color='k', linestyle ='-', lw=1)
plt.xlabel('S0')
plt.ylabel('Rho')
plt.title("Rho de l'autocall en fonction de S0")
plt.legend()
plt.grid(True)
plt.show()



#%%

# Fonction pour calculer l'epsilon de l'autocall
def autocall_epsilon(S0, q_ref, dq=0.1, r=r0, sigma=sigma0, T=T, m=m, N=N):
    price_plus = autocall_price_for_S0_fixed(S0, r=r0, q=q0+dq, sigma=sigma0, T=T, m=m, N=N)
    price_minus = autocall_price_for_S0_fixed(S0, r=r0, q=q0-dq, sigma=sigma0, T=T, m=m, N=N)
    return (price_plus - price_minus) / (2 * dq)

epsilon_S0 = np.array([autocall_epsilon(s, q_ref=q0) for s in S0_range])

plt.figure(figsize=(12, 5))
plt.plot(S0_range, epsilon_S0, marker='', linestyle='-', color='teal', label='Epsilon (sensi. dividendes)')
plt.axvline(x=VIS, color='black', linestyle='--', label='VIS')
plt.axvline(x=barriere_coupon, color='grey', linestyle='--', label='Barrière de protection/coupon')
plt.axhline(y=0, color='k', linestyle ='-', lw=1)
plt.xlabel('S0 (Valeur initiale du sous-jacent)')
plt.ylabel('Epsilon')
plt.title("Epsilon de l'autocall en fonction de S0")
plt.legend()
plt.grid(True)
plt.show()

#%%

# Afficher le graphique des données historiques de prix de Nvidia
df = pd.read_csv("data.csv")

df["Date"] = pd.to_datetime(df["Date"])

plt.figure(figsize=(12, 6))
plt.plot(df["Date"], df["Price"], marker='', linestyle='-', label='NVDA Spot Price')
plt.xlabel("Date")
plt.ylabel("NVDA Prix Spots (USD)")
plt.title("NVDA Prix Spots et barrières")
plt.axhline(y = VIS, color='black', linestyle='--', label='Barrière d\'autocall')
plt.axhline(y = barriere_coupon, color='grey', linestyle='--', label='Barrière de protection/coupon')
plt.xticks(rotation=45)
plt.grid(True)
plt.legend()
plt.show()

#%%

#Calcul de sensibilité aux différentes barrières

def autocall_price(S0, barriere_coupon, barriere_autocall, r=r0, q=q0, sigma=sigma0, T=T, m=m, N=N):
    VIS_local = VIS
    I0_local = I0
    Qj_local = C
    np.random.seed(42)
    traj = simulation_traj(S0, r, q, sigma, T, m, N)
    coupons_payes = np.zeros(N)
    for i in range(N):
        for t in range(1, m+1):
            if traj[t, i] >= barriere_autocall:
                coupons_payes[i] += Qj_local
                break  # Dès l'autocall, on arrête l'évaluation pour cette trajectoire
            elif traj[t, i] >= barriere_coupon:
                coupons_payes[i] += Qj_local
    IF = np.where(traj[-1] < barriere_coupon, 
                                I0_local * (traj[-1]/VIS_local),
                                I0_local)
    val_totale = IF + coupons_payes
    valeur_actuelle = np.exp(-r * T) * val_totale
    return np.mean(valeur_actuelle)

def sensi_coupon(S0, barrier_ref, d_barrier=0.01, **kwargs):
    price_plus = autocall_price(S0, barriere_coupon=barrier_ref + d_barrier,
                                barriere_autocall=barriere_autocall, **kwargs)
    price_minus = autocall_price(S0, barriere_coupon=barrier_ref - d_barrier,
                                 barriere_autocall=barriere_autocall, **kwargs)
    return (price_plus - price_minus) / (2 * d_barrier)

# Fonction de sensibilité par différences finies pour la barrière d'autocall.
# Ici, on fait varier barriere_autocall, en gardant la barrière de coupon fixe.
def sensi_autocall(S0, barrier_ref, d_barrier=0.01, **kwargs):
    price_plus = autocall_price(S0, barriere_coupon=barriere_coupon, barriere_autocall=barrier_ref + d_barrier, **kwargs)
    price_minus = autocall_price(S0, barriere_coupon=barriere_coupon, barriere_autocall=barrier_ref - d_barrier, **kwargs)
    return (price_plus - price_minus) / (2 * d_barrier)

S0_range = np.linspace(0, 2*16.25, 50)

# Calcul de la sensibilité pour chaque S0 pour la barrière de coupon, puis celle d'autocall
coupon_sensi = np.array([sensi_coupon(s0, barriere_coupon, d_barrier=0.01, r=r0, q=q0, sigma=sigma0, T=T, m=m, N=N)
                          for s0 in S0_range])

autocall_sensi = np.array([sensi_autocall(s0, barriere_autocall, d_barrier=0.01, r=r0, q=q0, sigma=sigma0, T=T, m=m, N=N)
                            for s0 in S0_range])

# Tracé des deux courbes sur le même graphique
plt.figure(figsize=(12, 6))
plt.plot(S0_range, coupon_sensi, linestyle='-', color='purple', lw=2, label="Sensibilité barrière (protection et coupon)")
plt.plot(S0_range, autocall_sensi, linestyle='-', color='red', lw=2, label="Sensibilité barrière (autocall)")
plt.axvline(x=VIS, color='black', linestyle='--', label='VIS')
plt.axvline(x=barriere_coupon, color='grey', linestyle='--', label='Barrière de protection/coupon')
plt.xlabel("S0 (Valeur initiale du sous-jacent)")
plt.ylabel("Sensibilité au niveau de la barrière")
plt.title("Effet de la variation des barrières sur le prix de l'autocall")
plt.legend()
plt.grid(True)
plt.show()