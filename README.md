Preliminaries:
1. Make account on developer.spotify.com, make a project and get client ID and client Secret
2. Save client ID and client Secret as client_id and client_secret, respectively in file 'config.R'


Steps to reproduce data:

1. Open 'Mining.R'
2. Change variable 'playlist_50s' to desired number of times to search for 50 playlists by each letter
2a. Alternatively, change 'playlist_50s' to 1 and change limit to a lower number in url1 (max is 50).
3. Run 'Mining.R', data will be saved to 'datamain.csv'