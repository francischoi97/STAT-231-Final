Preliminaries:
1. Make account on developer.spotify.com, make a project and get client ID and client Secret
2. Save client ID and client Secret as client_id and client_secret, respectively in file 'config.R'


Steps to reproduce data:

1. Open 'Mining.R'
2. Change variable 'playlist_50s' to desired number of times to search for 50 playlists by each letter
2a. Alternatively, change 'playlist_50s' to 1 and change limit to a lower number in url1 (max is 50).
3. Run 'Mining.R', data will be saved to 'datamain.csv'


Steps to get model:

1. Run 'modelselect.py' using python3
2. 'modelselect.py' will create 'playlistsummary.csv' which will show the summary data of each playlist, which will be the main data used to train the different models. The output of the print statements will be: 1) a list in the following format (RMSE, parameter, C value) and 2) an array with 12 error values of knn (k=25-49, increments of 2) and 10 error values of decision trees (depth=1-10, increments of 1)
3. From the print statements, select the model with the lowest error. This will be your best model, which should be manually updated in 'App.R'
