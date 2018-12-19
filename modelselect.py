import numpy as np
import sklearn
import warnings
import csv
import os.path
from math import sqrt
from six.moves import cPickle as pickle
from sklearn.metrics import classification_report
from sklearn.metrics import confusion_matrix
from sklearn.linear_model import LogisticRegression
from sklearn.neighbors import KNeighborsRegressor
from sklearn.tree import DecisionTreeRegressor
from sklearn.preprocessing import MinMaxScaler
from sklearn.model_selection import KFold
from sklearn.svm import SVR
from sklearn.metrics import f1_score
from sklearn.model_selection import cross_val_score
from sklearn.model_selection import train_test_split

def warn(*args, **kwargs):
	pass
warnings.warn = warn
warnings.simplefilter(action='ignore', category=FutureWarning)
warnings.simplefilter(action='ignore', category=DeprecationWarning)

def cross_validation(X, y, reg, evaler, num_folds):
    numDim = X.shape[1] # just helping out, technically didnt need
    runningSum = 0
    for index in range (0,num_folds):
        tempX = X.copy() #reset each time
        tempy = y.copy() #reset
        rows = 0 # for numpy, its more efficient to do this
        for iT in range(0,X.shape[0]): #seems stupid, turns out good for numpy
            if iT % num_folds == index:
                rows += 1
        validationSet = np.zeros((rows, numDim)) # initialize the validation stuff
        valiSety = np.zeros((rows, 2))
        tempCounter = 0 #book keeping pretty much
        for i in range (0,X.shape[0]):
            if i % num_folds == index:
                validationSet[tempCounter] = X[i] #those indexes
                valiSety[tempCounter] = y[i]
                
                tempX = np.delete(tempX, i - tempCounter, 0) #validation set, remove, care tempCounter
                tempy = np.delete(tempy,i - tempCounter, 0)
                tempCounter += 1
        reg.fit(tempX,tempy) #learn on the X left
        runningSum += evaler(valiSety, reg.predict(validationSet)) # evaluate on valiset predictions
        
    return runningSum / num_folds

if __name__ == "__main__":
	x = []
	with open('datamain.csv','rt', encoding="utf8") as f:
		reader = csv.reader(f)
		for line in reader:
			x.append(line)
	x.pop(0)

	x_train_playlist=[]
	y_train_playlist=[]
	data='"playlistName","numFollowers","numSongs","avgPopularity","avgSongLen","maxSongLen","minSongLen"'
	for y in x: #each playlist
		y_train_playlist.append(float(y[4])) #num followers

		if len(y[5])!=2:
			temp=y[5].replace("slashn","\n")
			names=temp.split("\n",1)[0]
			#column names: "info.id","artists","info.album.release_date","analysis.tempo","analysis.duration_ms","analysis.loudness","info.popularity"
			
			#temp 2: all column entries/song info
			temp2=temp.split("\n",1)[1]
			
			'''
			#for saving track info in playlist
			#Didn't end up using

			save_path = 'C:\\Users\\franc\\Documents\\STAT231\\final\\TracksInPlaylist'
			completeName = os.path.join(save_path, y[3]+".csv")         

			with open(completeName,'wt', encoding="utf8") as file:
				for line in temp2.splitlines():
					file.write(line)
					file.write("\n")
			'''

			x_train_song=[]
			y_train_song=[]

			numsongs=0
			totalpop=0
			totallen=0
			avgpop=0
			avglen=0
			maxlen=float("-inf")
			minlen=float("inf")
			#iterate through each song in playlist
			for line in temp2.splitlines():
				features=line.split(",")
				if len(features) == 7 and features[4] != 'NA': #Make sure the song has all the features necessary and has duration listed
					numsongs+=1
					totalpop+=float(features[6])
					totallen+=float(features[4])
					if float(features[4]) > maxlen:
						maxlen=float(features[4])
					if float(features[4]) < minlen:
						minlen=float(features[4])
			avgpop=totalpop/numsongs
			avglen=totallen/numsongs
			data+="\n"+y[3]+","+y[4]+","+str(numsongs)+","+str(avgpop)+","+str(avglen)+","+str(maxlen)+","+str(minlen)

	#Save the reorganized data as a csv
	save_path = 'C:\\Users\\franc\\Documents\\STAT231\\final'
	completeName = os.path.join(save_path, "playlistsummary.csv")         

	with open(completeName,'wt', encoding="utf8") as file:
		for line in data.splitlines():
			file.write(line)
			file.write("\n")

	z = []
	with open('playlistsummary.csv','rt', encoding="utf8") as f:
		reader = csv.reader(f)
		for line in reader:
			z.append(line)
	z.pop(0)

	#parse through the data and organize appropriately and get it into the correct format
	x_train=[]
	y_train=[]
	for n in z:
		y_train.append(float(n[1]))
		feats=[]
		for f in range(3,len(n)-3):
			feats.append(float(n[f]))
		x_train.append(feats)
	
	
	X_train=np.asarray(x_train)
	Y_train=np.asarray(y_train)
	X_tr, X_te, y_tr, y_te = train_test_split(X_train, Y_train) #split into test and train data so we can perform cross validation later
	
	best=[0,0,float("inf")] #should contain C value, model parameter, and MSE of best model
	for h in range(4):
		C=pow(10,h)
		for j in range(5): 
			gamma=1/pow(10,j)
			degree=j+2
			r=pow(10,j-1)
			k=2*j+1

			rbf = SVR(C=C, kernel='rbf', gamma=gamma)
			poly =  SVR(C=C, kernel='poly', degree=degree)
			sigmoid = SVR(C=C, kernel='sigmoid', coef0=r)

			#Did not end up performing regression using polynomial SVMs since it takes far too long

			rbf.fit(X_train, Y_train)
			#poly.fit(X_tr, y_tr)
			sigmoid.fit(X_train, Y_train)

			errorrbf = -np.mean(cross_val_score(rbf, X_train, Y_train, cv=5, scoring='neg_mean_squared_error'))
			#errorpoly = np.mean(cross_val_score(poly, X_tr, y_tr, cv=5, scoring='neg_mean_squared_error'))
			errorsigmoid = -np.mean(cross_val_score(sigmoid, X_train, Y_train, cv=5, scoring='neg_mean_squared_error'))

			if(errorrbf<best[2]):
				best[2]=sqrt(errorrbf)
				best[1]="gamma = "+str(gamma)
				best[0]=C
				'''
			if(errorpoly>best[2]):
				best[2]=errorpoly
				best[1]="degree = "+str(degree)
				best[0]=C
				'''
			if(errorsigmoid<best[2]):
				best[2]=sqrt(errorsigmoid)
				best[1]="r = "+str(r)
				best[0]=C
	print(best) #prints the error and parameters of the best SVM model
	
	zeroSums = np.zeros((22))
	count = 0
	#Knn
	neighborList = [2*x+25 for x in range(12)] #k=25-49
	for value in neighborList:
		kNeighbors = KNeighborsRegressor(n_neighbors = value)
		zeroSums[count] = sqrt(-np.mean(cross_val_score(kNeighbors, X_tr, y_tr, cv=10, scoring='neg_mean_squared_error')))
		count +=1

	#Decision Tree
	depthList = [x+1 for x in range(10)] #depth 1-10
	for depth in depthList:
		dTree = DecisionTreeRegressor(max_depth = depth)
		zeroSums[count] = sqrt(-np.mean(cross_val_score(dTree, X_tr, y_tr, cv=10, scoring='neg_mean_squared_error')))
		count +=1

	print(zeroSums) #prints the different errors of each knn, decision tree in an array in order of the tests 
