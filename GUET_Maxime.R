#Projet Analyse R

setwd("C:/Users/maxgu/OneDrive/EDHEC/M1/Analyse de données/Projet analyse")

projet <- read.csv("projet.csv", header = TRUE, sep = ",", dec = ".", stringsAsFactors = TRUE)

str(projet)
summary(projet)

projet <- projet[,-1]

#Verification des valeurs manquantes
colSums(projet == 999)
colSums(is.na(projet))

#Histogrammes pour visualiser les distributions
hist(projet$age, main = "Distribution age", xlab = "age", col = "lightblue",xlim=c(0,150))
hist(projet$revenus, main = "Distribution Revenus", xlab = "Revenus (en milliers de $)", col = "lightgreen", xlim=c(0,500))

#table de frequence pour les variables categorielles
prop.table(table(projet$education))*100
plot(table(projet$education), main = "Repartition des niveaux d'education", col = "orange")

#Repartition defaut
prop.table(table(projet$defaut))
plot(table(projet$defaut), main = "Repartition des defauts de paiement", col = "red")

#pretraitement
#Remplaçons les donnees manquantes par la médiane de la colonne

median_age <- median(projet$age[projet$age != 999])
projet$age[projet$age == 999] <- median_age

median_adresse <- median(projet$adresse[projet$adresse != 999])
projet$adresse[projet$adresse == 999] <- median_adresse

#On fait en sorte que les variables categorielles sont definies comme des facteurs
projet$education <- factor(projet$education, levels = c("Niveau bac", "Bac+2", "Bac+3", "Bac+4", "Bac+5 et plus"))
projet$defaut <- factor(projet$defaut, levels = c("Non", "Oui"))

#Verif des outliers avec boxplot
boxplot(projet$revenus, main = "Revenus", col = "lightblue")
projet$revenus <- scale(projet$revenus)
boxplot(projet$debcred, main = "debcred", col = "lightblue")
projet$debcred <- scale(projet$debcred)
boxplot(projet$debcarte, main = "debcarte", col = "lightblue")
projet$debcarte <- scale(projet$debcarte)
boxplot(projet$autres, main = "autres dettes", col = "lightblue")
projet$autres <- scale(projet$autres)

projet$revenus <- as.numeric(projet$revenus)
projet$debcred <- as.numeric(projet$debcred)
projet$debcarte <- as.numeric(projet$debcarte)
projet$autres <- as.numeric(projet$autres)

#Sauvegarde des donnees pretraitement
write.csv(projet, "projet_PT.csv", row.names = FALSE)
projet <- read.csv("projet_PT.csv", header = TRUE, sep = ",", dec = ".")
summary(projet)

#Clustering
install.packages("cluster")
install.packages("ggplot2")
library(cluster)
library(ggplot2)

projet$education <- factor(as.factor(projet$education), ordered=TRUE)
mode(projet$education)
class(projet$education)
str(projet)
summary(projet)

#matrice de distance
projet$defaut <- factor(projet$defaut, levels=c("Non", "Oui"))
dmatrix <- daisy(projet)

#test en fixant le nbr de clusters à 4 avec le kmeans
km4 <- kmeans(dmatrix, 4)
table(km4$cluster, projet$defaut)
qplot(km4$cluster, data=projet, fill=defaut)
qplot(revenus, as.factor(km4$cluster), data=projet, color=defaut) + geom_jitter(width = 0.3, height = 0.3)
qplot(age, as.factor(km4$cluster), data=projet, color=defaut) + geom_jitter(height = 0.3)
qplot(debcarte, as.factor(km4$cluster), data=projet, color=defaut) + geom_jitter(height = 0.3)
qplot(debcred, as.factor(km4$cluster), data=projet, color=defaut) + geom_jitter(height = 0.3)
qplot(education, as.factor(km4$cluster), data=projet, color=defaut) + geom_jitter(height = 0.3)

projet_km4 <- data.frame(projet)
projet_km4$Cluster <- km4$cluster
View(projet_km4)

#Evaluation interne des clusters
install.packages("tsne")
library(tsne)
set.seed(10000)

#ici j'utilise un échantillon de la matrice initiale car la fonction tsne met trop de temps à s'exécuter sinon

dmatrix_sample <- daisy(projet[1:500,])
km4 <- kmeans(dmatrix_sample, 4)
table(km4$cluster, projet$defaut[1:500])
qplot(km4$cluster, data=projet[1:500,], fill=defaut)
qplot(revenus, as.factor(km4$cluster), data=projet[1:500,], color=defaut) + geom_jitter(width = 0.3, height = 0.3)
qplot(age, as.factor(km4$cluster), data=projet[1:500,], color=defaut) + geom_jitter(height = 0.3)
qplot(debcarte, as.factor(km4$cluster), data=projet[1:500,], color=defaut) + geom_jitter(height = 0.3)
qplot(debcred, as.factor(km4$cluster), data=projet[1:500,], color=defaut) + geom_jitter(height = 0.3)
qplot(education, as.factor(km4$cluster), data=projet[1:500,], color=defaut) + geom_jitter(height = 0.3)

tsne_out <- tsne(dmatrix_sample, k=2)
tsne_out <- data.frame(tsne_out)
qplot(tsne_out[,1], tsne_out[,2], col=as.factor(km4$cluster))

#variation du nbr de clusters
set.seed(10000)
for (k in 3:7){
  km <- kmeans(dmatrix_sample, k)
  print(table(km$cluster, projet$defaut[1:500]))
  print(qplot(km$cluster, data=projet[1:500,], fill=defaut))
  print(qplot(tsne_out[,1], tsne_out[,2], col=as.factor(km$cluster)))
}  

#on obtient alors que k = 3 est optimal comme la proportion d'instances de chque classe est maximale et les points appartenant au même cluster sont mieux regroupés dans les nuages de points 
#On applique donc le clustering pour k = 3

km3 <- kmeans(dmatrix, 3)
projet$Cluster <- km3$cluster

#calcul de l'age moyen des clients par cluster
print(mean(projet$age[projet$Cluster == 1]))
print(mean(projet$age[projet$Cluster == 2]))
print(mean(projet$age[projet$Cluster == 3]))

#niveau d'education le plus frequent par cluster
prop.table(table(projet$education[projet$Cluster == 1]))*100
prop.table(table(projet$education[projet$Cluster == 2]))*100
prop.table(table(projet$education[projet$Cluster == 3]))*100

#Revenus moyens par cluster => on doit traiter avec les données non normalisées
projet_init <- read.csv("projet.csv", header = TRUE, sep = ",", dec = ".", stringsAsFactors = TRUE)
projet_init <- projet[,-1]
projet_init$Cluster <- km3$cluster
print(mean(projet_init$revenus[projet_init$Cluster == 1]))*1000
print(mean(projet_init$revenus[projet_init$Cluster == 2]))*1000
print(mean(projet_init$revenus[projet_init$Cluster == 3]))*1000

#moyenne du nbr d'années avec l'employeur actuel
print(mean(projet_init$emploi[projet_init$Cluster == 1]))
print(mean(projet_init$emploi[projet_init$Cluster == 2]))
print(mean(projet_init$emploi[projet_init$Cluster == 3]))

#nombre moyen d'annees a l'adress actuelle
print(mean(projet$adresse[projet_init$Cluster == 1]))
print(mean(projet$adresse[projet_init$Cluster == 2]))
print(mean(projet$adresse[projet_init$Cluster == 3]))

#debcarte moyen par cluster
print(mean(projet_init$debcarte[projet_init$Cluster == 1]))*1000
print(mean(projet_init$debcarte[projet_init$Cluster == 2]))*1000
print(mean(projet_init$debcarte[projet_init$Cluster == 3]))*1000

#debcred moyen par cluster
print(mean(projet_init$debcred[projet_init$Cluster == 1]))
print(mean(projet_init$debcred[projet_init$Cluster == 2]))
print(mean(projet_init$debcred[projet_init$Cluster == 3]))

#autres dettes en moyenne par cluster
print(mean(projet_init$autres[projet_init$Cluster == 1]))*1000
print(mean(projet_init$autres[projet_init$Cluster == 2]))*1000
print(mean(projet_init$autres[projet_init$Cluster == 3]))*1000

#definir methode d'evaluation des classifieurs
projet_EA <- projet[1:5000,]
projet_ET <- projet[5001:6000,]
projet_EA <- projet_EA[,-4]
projet_EA <- projet_EA[,-10]
View(projet_EA)

install.packages("rpart")
install.packages("C50")
install.packages("tree")
library(rpart)
library(C50)
library(tree)

#avec rpart()
tree1 <- rpart(defaut~., projet_EA)
plot(tree1)
text(tree1, pretty = 0)
library(rpart.plot)
rpart.plot(tree1, cex=0.6)

#avec C5.0
tree2 <- C5.0(defaut ~ ., data = projet_EA)

#avec tree
tree3 <- tree(defaut~., data=projet_EA)
plot(tree3)
text(tree3, pretty = 0)

test_tree1 <- predict(tree1, projet_ET, type="class")
test_tree2 <- predict(tree2, projet_ET, type="class")
test_tree3 <- predict(tree3, projet_ET, type="class")
table(test_tree1)
table(test_tree2)
table(test_tree3)

#calcul des taux de succès
projet_ET$Tree1 <- test_tree1
projet_ET$Tree2 <- test_tree2
projet_ET$Tree3 <- test_tree3
View(projet_ET)
taux_succes1 <- nrow(projet_ET[projet_ET$defaut==projet_ET$Tree1,])/nrow(projet_ET)
taux_succes2 <- nrow(projet_ET[projet_ET$defaut==projet_ET$Tree2,])/nrow(projet_ET)
taux_succes3 <- nrow(projet_ET[projet_ET$defaut==projet_ET$Tree3,])/nrow(projet_ET)

print(taux_succes1)
print(taux_succes2)
print(taux_succes3)

#matrices de confusion
mc_tree2 <- table(projet_ET$defaut, test_tree2)
mc_tree2
# Rappel
mc_tree2[2,2]/(mc_tree2[2,2]+mc_tree2[2,1])

mc_tree1 <- table(projet_ET$defaut, test_tree1)
mc_tree1
#rappel
mc_tree1[2,2]/(mc_tree1[2,2]+mc_tree1[2,1])

mc_tree3 <- table(projet_ET$defaut, test_tree3)
mc_tree3
#rappel
mc_tree3[2,2]/(mc_tree3[2,2]+mc_tree3[2,1])

#parametrage pour le classifieur optimal (tree3)
tree_tr1 <- tree(defaut~., projet_EA, split = "deviance", control = tree.control(nrow(projet_EA), mincut = 10))
tree_tr2 <- tree(defaut~., projet_EA, split = "deviance", control = tree.control(nrow(projet_EA), mincut = 5))
tree_tr3 <- tree(defaut~., projet_EA, split = "gini", control = tree.control(nrow(projet_EA), mincut = 10))
tree_tr4 <- tree(defaut~., projet_EA, split = "gini", control = tree.control(nrow(projet_EA), mincut = 7))

test_tr1 <- predict(tree_tr1, projet_ET, type="class")
print(taux_tr1 <- nrow(projet_ET[projet_ET$defaut==test_tr1,])/nrow(projet_ET))
print(mc_tree_tr1 <- table(projet_ET$defaut, test_tr1))
print(mc_tree_tr1[2,2]/(mc_tree_tr1[2,2]+mc_tree_tr1[2,1]))
#taux de succes et rappel equivalents

test_tr2 <- predict(tree_tr2, projet_ET, type="class")
print(taux_tr2 <- nrow(projet_ET[projet_ET$defaut==test_tr2,])/nrow(projet_ET))
print(mc_tree_tr2 <- table(projet_ET$defaut, test_tr2))
print(mc_tree_tr2[2,2]/(mc_tree_tr2[2,2]+mc_tree_tr2[2,1]))
#taux de succes et rappel equivalents


test_tr3 <- predict(tree_tr3, projet_ET, type="class")
print(taux_tr3 <- nrow(projet_ET[projet_ET$defaut==test_tr3,])/nrow(projet_ET))
print(mc_tree_tr3 <- table(projet_ET$defaut, test_tr3))
print(mc_tree_tr3[2,2]/(mc_tree_tr3[2,2]+mc_tree_tr3[2,1]))
#taux de succès equivalent mais rappel plus faible

test_tr4 <- predict(tree_tr4, projet_ET, type="class")
print(taux_tr4 <- nrow(projet_ET[projet_ET$defaut==test_tr4,])/nrow(projet_ET))
print(mc_tree_tr4 <- table(projet_ET$defaut, test_tr4))
print(mc_tree_tr4[2,2]/(mc_tree_tr4[2,2]+mc_tree_tr4[2,1]))
#rappel plus eleve et taux de succès équivalent
#tree_tr4 est le classifieur optimal ici
# Spécificité
mc_tree_tr4[1,1]/(mc_tree_tr4[1,1]+mc_tree_tr4[1,2])
# Précision 
mc_tree_tr4[2,2]/(mc_tree_tr4[2,2]+mc_tree_tr4[1,2])
# Taux de Vrais Négatifs 
mc_tree_tr4[1,1]/(mc_tree_tr4[1,1]+mc_tree_tr4[2,1])

tree_opt <- tree_tr4

#Application du classifieur choisi aux données à prédire
projet_PR <-  read.csv("projet_new.csv", header = TRUE, sep = ",", dec = ".", stringsAsFactors = TRUE)

View(projet_PR)

#traitement des valeurs manquantes
median_age <- median(projet_PR$age[projet_PR$age != 999])
projet_PR$age[projet_PR$age == 999] <- median_age

median_adresse <- median(projet_PR$adresse[projet_PR$adresse != 999])
projet_PR$adresse[projet_PR$adresse == 999] <- median_adresse

#On fait en sorte que les variables categorielles sont definies comme des facteurs
projet_PR$education <- factor(projet_PR$education, levels = c("Niveau bac", "Bac+2", "Bac+3", "Bac+4", "Bac+5 et plus"))

#Normalisation des données
projet_PR$revenus <- scale(projet_PR$revenus)
projet_PR$debcred <- scale(projet_PR$debcred)
projet_PR$debcarte <- scale(projet_PR$debcarte)
projet_PR$autres <- scale(projet_PR$autres)

projet_PR$revenus <- as.numeric(projet_PR$revenus)
projet_PR$debcred <- as.numeric(projet_PR$debcred)
projet_PR$debcarte <- as.numeric(projet_PR$debcarte)
projet_PR$autres <- as.numeric(projet_PR$autres)

class_tree_opt <- predict(tree_opt, projet_PR, type="class")
projet_PR$Prediction <- class_tree_opt
prob_tree_opt <- predict(tree_opt, projet_PR, type="vector")

resultat <- data.frame(projet_PR$client, projet_PR$Prediction, prob_tree_opt[,2], prob_tree_opt[,1])
View(resultat)
colnames(resultat) = list("Client", "Prediction", "P(Oui)", "P(Non)")

#repartition des classes
ouidefaut <- nrow(resultat[resultat$Prediction=="Oui",])
ouidefaut/500
nondefaut <- nrow(resultat[resultat$Prediction=="Non",])
nondefaut/500

#calculs des probabilites maximales, minimales, moyennes
View(resultat$`P(Oui)`)
min_proba_oui <- min(resultat$`P(Oui)`)
min_proba_oui
max_proba_oui <- max(resultat$`P(Oui)`)
max_proba_oui
min_proba_non <- min(resultat$`P(Non)`)
min_proba_non
max_proba_non <- max(resultat$`P(Non)`)
max_proba_non
moyenne_proba_oui <- mean(resultat$`P(Oui)`)
moyenne_proba_oui
moyenne_proba_non <- mean(resultat$`P(Non)`)
moyenne_proba_non

#Fichier contenant les prédictions
write.csv(resultat, "resultat.csv", row.names = FALSE)
                         