' *********************************************************
' *********************************************************
' **
' **  Rokagram Channel
' **
' **  W. Pinkman, February 2014
' **
' **  Copyright (c) 2014 Fugue State, Inc., All Rights Reserved.
' **
' *********************************************************
' *********************************************************

' Section users
'    "1031318142" = 1031318142.b13119e.1a17881dba434453950210394ea8106d
'  Section users/1031318142
'     "full_name" = 
'     "profile_picture" = http://images.ak.instagram.com/profiles/anonymousUser.jpg
'     "username" = whoabill


Function CreatePosterScreen() As Object

	this = {
	
		port: CreateObject("roMessagePort"),
		screen: CreateObject("roPosterScreen"),
		busyDialog: CreateObject("roOneLineDialog"),
		
		busyShowing: invalid,
		user: AutoLogin(),
		users: invalid,
		
		contentList: [],
		reqHash: {},
		userInfoReqHash: {},
		
		AddPopularItem: PosterScreenAddPopularItem,
		' sub popular
		AddFeaturedUserItem: PosterScreenAddFeaturedUserItem,
		AddInstaDailyItem: PosterScreenAddInstaDailyItem,
		AddCelebritiesItem: PosterScreenAddCelebritiesItem,
		AddBeautyItem: PosterScreenAddBeautyItem,
		AddTrendingItem: PosterScreenAddTrendingItem,

		AddLocationsItem: PosterScreenAddLocationsItem,
		' sub locataion
		AddLocalItem: PosterScreenAddLocalItem,
		AddLocationItem: PosterScreenAddLocationItem,
		
		AddSearchTagsItem: PosterScreenAddSearchTagsItem,
		AddSearchUsersItem: PosterScreenAddSearchUsersItem,
		AddUserItem: PosterScreenAddUserItem,
		AddLinkUserItem: PosterScreenAddLinkUserItem,
		AddAudioSettingsItem: PosterScreenAddAudioSettingsItem,
		AddAboutItem: PosterScreenAddAboutItem,
		
		AddPostsItem: PosterScreenAddPostsItem,
		AddFeedItem: PosterScreenAddFeedItem,
		AddLikesItem: PosterScreenAddLikesItem,
		
		SetFocusedListItem: PosterScreenSetFocusedListItem,
		GetSelectionRegKey: PosterScreenGetSelectionRegKey,
		
		HandleInstagramMediaResponse: PosterScreenHandleInstagramMediaResponse,
		HandleInstagramUserInfoResponse: PosterScreenHandleInstagramUserInfoResponse,
		
		RefreshContent: PosterScreenRefreshContent,
		Reset: function() : m.contentList = [] : m.reqHash = {} : return invalid : end function
		Show: PosterScreenShow,
		Run: PosterScreenRun
		
	}

	this.screen.SetMessagePort(this.port)
	this.screen.SetCertificatesFile("common:/certs/ca-bundle.crt")
	this.screen.InitClientCertificates()

	this.busyDialog.SetMessagePort(this.port)
	
	this.screen.SetListStyle("arced-square")

	SetBreadcrumb(this.screen)
    
	return this
	
End Function

Sub PosterScreenShow()

	m.screen.Show()

	if m.posterType <> invalid 
		GaScreenView(m.posterType).PostAsync()
	else
		GaScreenView("main").SetSessionStart().PostAsync()
	end if
	
End Sub

Sub PosterScreenRefreshContent()
	m.screen.SetContentList(m.contentList)
End Sub

Sub PosterScreenAddFeaturedUserItem(featuredUser)

	meta = {}
	meta.ShortDescriptionLine1 = featuredUser.username
	meta.ShortDescriptionLine2 = featuredUser.full_name + " on Instagram"
	meta.NoContent = "Instagram is not returning any content for this selection right now.  Please try again later."
	
	meta.instaRequest = CreateInstaRequest(m.port)
	meta.instaRequest.endpoint = "/users/" + featuredUser.id + "/media/recent"
	meta.timespan = CreateObject("roTimeSpan")
	meta.instaRequest.StartGetToString()
	m.reqHash[Stri(meta.instaRequest.identity)] = meta
	
	meta.onselect = "slideshow"
	
	meta.key = featuredUser.id
	m.contentList.Push(meta)


End Sub

Sub PosterScreenAddInstaDailyItem()

	dt = CreateObject("roDateTime")
	dt.ToLocalTime()
	
	weekday = dt.GetWeekday()
	
	if weekday = "Sunday"
		dow = 0
	else if weekday = "Monday"
		dow = 1
	else if weekday = "Tuesday"
		dow = 2
	else if weekday = "Wednesday"
		dow = 3
	else if weekday = "Thursday"
		dow = 4
	else if weekday = "Friday"
		dow = 5
	else if weekday = "Saturday"
		dow = 6
	else
		dow = GetDayOfWeek(dt)
		LogDebugMessage("dow:" + Stri(dow) + ", weekday: " + weekday)
	end if
	
	featuredTag = invalid
	
	globals = GetGlobals()
		
	featuredTag = globals.instadaily[dow].featuredTag
	description = globals.instadaily[dow].description
	
	if featuredTag <> invalid
		meta = {}
		meta.ShortDescriptionLine1 = "#" + featuredTag
		meta.ShortDescriptionLine2 = description
		meta.NoContent = "Instagram is not returning any content for this selection right now.  Please try again later."
		
		meta.instaRequest = CreateInstaRequest(m.port)
		meta.instaRequest.endpoint = "/tags/" + featuredTag + "/media/recent"
		meta.timespan = CreateObject("roTimeSpan")
		meta.instaRequest.StartGetToString()
		m.reqHash[Stri(meta.instaRequest.identity)] = meta
		
		meta.onselect = "slideshow"
		
		meta.key = "instadaily"
		m.contentList.Push(meta)
	end if
End Sub

Sub PosterScreenAddCelebritiesItem()
	meta = {}
	meta.ShortDescriptionLine1 = "Famous"
	meta.ShortDescriptionLine2 = "Celebrities on Instagram"
	meta.NoContent = "Instagram is not returning any content for this selection right now.  Please try again later."
	
	meta.instaRequest = CreateInstaRequest(m.port)
	meta.instaRequest.endpoint = "/users/self/feed"
	accessTokenLocalhost = "1174294793.c54578d.7e83132ea01d4d45b6d9aa4a35a61bcc"
	meta.instaRequest.access_token = accessTokenLocalhost
	meta.timespan = CreateObject("roTimeSpan")
	meta.instaRequest.StartGetToString()
	m.reqHash[Stri(meta.instaRequest.identity)] = meta
	
	meta.onselect = "slideshow"
	meta.key = "famous"
		
	m.contentList.Push(meta)
End Sub

Sub PosterScreenAddBeautyItem()
	globals = GetGlobals()
	
	meta = {}
	meta.ShortDescriptionLine1 = "Beautiful"
	meta.ShortDescriptionLine2 = "Beauty on Instagram"
	meta.NoContent = "Instagram is not returning any content for this selection right now.  Please try again later."
	
	meta.instaRequest = CreateInstaRequest(m.port)
	meta.instaRequest.endpoint = globals.feeds.beauty.endpoint
	meta.instaRequest.access_token = globals.feeds.beauty.access_token
	meta.timespan = CreateObject("roTimeSpan")
	meta.instaRequest.StartGetToString()
	m.reqHash[Stri(meta.instaRequest.identity)] = meta
	
	meta.onselect = "slideshow"
	meta.key = "beauty"
		
	m.contentList.Push(meta)
End Sub

Sub PosterScreenAddTrendingItem()

	m.popularMeta = {}
	m.popularMeta.ShortDescriptionLine1 = "Trendy"
	m.popularMeta.ShortDescriptionLine2 = "Trending on Instagram"
	m.popularMeta.NoContent = "Instagram is not returning any content for this selection right now.  Please try again later."
	
		
	if m.popularMeta.instaRequest = invalid then
		m.popularMeta.instaRequest = CreateInstaRequest(m.port)
		m.popularMeta.instaRequest.endpoint = "/media/popular"
		
		if m.topParsedResponse <> invalid AND m.topParsedResponse.data.Count() > 0
			m.popularMeta.parsedResponse = m.topParsedResponse 
			m.popularMeta.instaRequest = m.topInstaRequest
			coverUrl = HackStripHttps(m.topParsedResponse.data[0].images.low_resolution.url)
			m.popularMeta.HdPosterUrl = coverUrl
			m.popularMeta.SdPosterUrl = coverUrl
			m.RefreshContent()
			m.topParsedResponse = invalid
		else
			m.popularMeta.instaRequest.StartGetToString()
			m.reqHash[Stri(m.popularMeta.instaRequest.identity)] = m.popularMeta
		end if
	end if
	
	m.popularMeta.onselect = "slideshow"
	m.popularMeta.key = "trending"
	m.contentList.Push(m.popularMeta)
	
End Sub


Sub PosterScreenAddLocationItem(location)
	meta = {}
	meta.ShortDescriptionLine1 = location.name
	meta.ShortDescriptionLine2 = "Posts take at " + location.name
	meta.NoContent = "Instagram is not returning any content for this selection right now.  Please try again later."
		
	meta.instaRequest = CreateInstaRequest(m.port)
	meta.instaRequest.endpoint = "/locations/" + location.id + "/media/recent"
	
		
	meta.instaRequest.StartGetToString()
	m.reqHash[Stri(meta.instaRequest.identity)] = meta
	
	meta.onselect = "slideshow"
	meta.key = "location-" + location.id
	
	m.contentList.Push(meta)

End Sub


Sub PosterScreenAddPopularItem()

	m.popularMeta = {}
	m.popularMeta.ShortDescriptionLine1 = "Popular"
	m.popularMeta.ShortDescriptionLine2 = "Trending, Celebrities, and more"
	m.popularMeta.NoContent = "Instagram is not returning any content for this selection right now.  Please try again later."
	
	if m.popularMeta.instaRequest = invalid then
    	m.popularMeta.instaRequest = CreateInstaRequest(m.port)
    	m.popularMeta.instaRequest.endpoint = "/media/popular"
    	if GetCurrentUser() <> invalid then
    		m.popularMeta.instaRequest.access_token = m.user.access_token
    	end if
    	m.popularMeta.timespan = CreateObject("roTimeSpan")
    	m.popularMeta.instaRequest.StartGetToString()
    	m.reqHash[Stri(m.popularMeta.instaRequest.identity)] = m.popularMeta
	end if
	
	m.popularMeta.onselect = "popular-poster"
	m.popularMeta.key = "popular"
	m.contentList.Push(m.popularMeta)

End Sub

Sub PosterScreenAddLocationsItem()

    inlist = true
    if m.localMeta = invalid then
		m.localMeta = {}
    	inlist = false
    end if
	m.localMeta.ShortDescriptionLine1 = "Locations"
	location = ReadLocation()
	if location <> invalid then
		m.localMeta.ShortDescriptionLine2 = "Local and Popular Locations"
		if m.localMeta.instaRequest = invalid then
			m.localMeta.instaRequest = CreateInstaRequest(m.port)
			m.localMeta.instaRequest.AddQueryParam("lat", location.latitude)
			m.localMeta.instaRequest.AddQueryParam("lng", location.longitude)
			m.localMeta.instaRequest.AddQueryParam("distance", "5000")
	    	'if GetCurrentUser() <> invalid then
	    	'	m.localMeta.instaRequest.access_token = m.user.access_token
	    	'end if
			
			m.localMeta.instaRequest.endpoint = "/media/search"
			m.localMeta.instaRequest.StartGetToString()
			m.reqHash[Stri(m.localMeta.instaRequest.identity)] = m.localMeta
		end if
		
		
		m.localMeta.onselect = "locations-poster"
		m.localMeta.key = "local"
		m.contentList.Push(m.localMeta)
	end if

End Sub

Sub PosterScreenAddLocalItem()
	meta = {}
	meta.ShortDescriptionLine1 = "Local"
		
	location = ReadLocation()
	if location <> invalid AND location.latitude <> "0.0" AND location.longitude <> "0.0"
		meta.ShortDescriptionLine2 = "Posts near " + location.city
		meta.NoContent = "Instagram is not returning any content for this selection right now.  Please try again later."
		
		meta.instaRequest = CreateInstaRequest(m.port)
		meta.instaRequest.AddQueryParam("lat", location.latitude)
		meta.instaRequest.AddQueryParam("lng", location.longitude)
		meta.instaRequest.AddQueryParam("distance", "5000")
		meta.instaRequest.endpoint = "/media/search"
				
		if m.topParsedResponse <> invalid AND m.topParsedResponse.data.Count() > 0
			meta.parsedResponse = m.topParsedResponse 
			coverUrl = HackStripHttps(m.topParsedResponse.data[0].images.low_resolution.url)
			meta.HdPosterUrl = coverUrl
			meta.SdPosterUrl = coverUrl
			m.topParsedResponse = invalid
		else
			meta.timespan = CreateObject("roTimeSpan")
			meta.instaRequest.StartGetToString()
			m.reqHash[Stri(meta.instaRequest.identity)] = meta
		end if
		
		meta.onselect = "slideshow"
		meta.key = "local"
			
		m.contentList.Push(meta)
		m.RefreshContent()
	end if
	
End Sub

Sub PosterScreenAddSearchTagsItem()
	m.searchMeta = {}
	m.searchMeta.ShortDescriptionLine1 = "Search"
	m.searchMeta.ShortDescriptionLine2 = "Search Hashtags"
	m.searchMeta.HdPosterUrl = "pkg:/images/tsearch-HD.jpg"
	m.searchMeta.SdPosterUrl = "pkg:/images/tsearch-SD.jpg"
		
	m.searchMeta.key = "search-tags"
	m.searchMeta.onselect = "search-tags"
	m.contentList.Push(m.searchMeta)
End Sub

Sub PosterScreenAddSearchUsersItem()
	m.searchUsersMeta = {}
	m.searchUsersMeta.ShortDescriptionLine1 = "Search"
	m.searchUsersMeta.ShortDescriptionLine2 = "Search Users"
	m.searchUsersMeta.HdPosterUrl = "pkg:/images/usearch-HD.jpg"
	m.searchUsersMeta.SdPosterUrl = "pkg:/images/usearch-SD.jpg"
		
	m.searchUsersMeta.key = "search-users"
	m.searchUsersMeta.onselect = "search-users"
	m.contentList.Push(m.searchUsersMeta)
End Sub

Sub PosterScreenAddUserItem(user, visible)
		
	userMeta = {}
	userMeta.ShortDescriptionLine1 = user.username
	userMeta.ShortDescriptionLine2 = user.full_name
	userMeta.HdPosterUrl = user.profile_picture
	userMeta.SdPosterUrl = user.profile_picture
	
	userMeta.instaRequest = CreateInstaRequest(m.port)
	userMeta.instaRequest.endpoint = "/users/" + user.id
	userMeta.instaRequest.access_token = user.access_token
	userMeta.timespan = CreateObject("roTimeSpan")
	userMeta.instaRequest.StartGetToString()
	
	
	userMeta.user = user
	userMeta.key = user.id
	userMeta.onselect = "userposter"
		
	m.userInfoReqHash[Stri(userMeta.instaRequest.identity)] = userMeta
	
	if (visible)
		m.contentList.Push(userMeta)
	end if

End Sub

Sub PosterScreenAddAboutItem()
	aboutMeta = {}
	aboutMeta.ShortDescriptionLine1 = "About Rokagram"
	aboutMeta.HdPosterUrl = "pkg:/images/camera-poster-hd.jpg"
	aboutMeta.SdPosterUrl = "pkg:/images/camera-poster-sd.jpg"
		
	aboutMeta.key = "about"
	aboutMeta.onselect = "aboutposter"
		
	m.contentList.Push(aboutMeta)

End Sub

Sub PosterScreenAddLinkUserItem()
	regScreenMeta = {}
	if GetUsersList().Count() > 0 then
		regScreenMeta.ShortDescriptionLine1 = "Add Another"
	else 
		regScreenMeta.ShortDescriptionLine1 = "Add Account"
	end if
	regScreenMeta.ShortDescriptionLine2 = "Link an Instagram Account"
	
	regScreenMeta.HdPosterUrl = "pkg:/images/useradd-hd.png"
	regScreenMeta.SdPosterUrl = "pkg:/images/useradd-sd.png"
	regScreenMeta.onselect = "regscreen"
	m.contentList.Push(regScreenMeta)
End Sub

Sub PosterScreenAddAudioSettingsItem()
	 meta = {}
	 meta.ShortDescriptionLine1 = "Music Settings"
	 meta.ShortDescriptionLine2 = "Choose music"
	 meta.HdPosterUrl = "pkg:/images/headphones-hd.png"
	 meta.SdPosterUrl = "pkg:/images/headphones-sd.png"
		 
	 meta.onselect = "audioSettings"
     meta.key = meta.onselect 
	 m.contentList.Push(meta)
End Sub	    	

Sub PosterScreenAddPostsItem()
	    	
	user = GetCurrentUser()
	meta = {}
	meta.ShortDescriptionLine1 = "Posts"
	meta.ShortDescriptionLine2 = user.username + "'s Posts"
	meta.NoContent = "The photos you post to your Instagram account will appear here."
	
	if meta.instaRequest = invalid then
		meta.instaRequest = CreateInstaRequest(m.port)
		meta.instaRequest.access_token = user.access_token
		meta.instaRequest.endpoint = "/users/" + user.id + "/media/recent"
		meta.instaRequest.StartGetToString()
		m.reqHash[Stri(meta.instaRequest.identity)] = meta
	end if
	
	meta.onselect = "slideshow"
	meta.key =  "posts" 
	m.contentList.Push(meta)

End Sub

Sub PosterScreenAddFeedItem()
	user = GetCurrentUser()
	meta = {}
	meta.ShortDescriptionLine1 = "Feed"
	meta.ShortDescriptionLine2 = user.username + "'s Feed"
	meta.NoContent = "Photos from your Instagram feed will appear here."

	
	if meta.instaRequest = invalid then
		meta.instaRequest = CreateInstaRequest(m.port)
		'meta.instaRequest.access_token = user.access_token
		meta.instaRequest.endpoint = "/users/self/feed"
		meta.instaRequest.AddQueryParam("count", "20")
		meta.instaRequest.StartGetToString()
		m.reqHash[Stri(meta.instaRequest.identity)] = meta
	end if
	
	meta.onselect = "slideshow"
	meta.key = "feed"
	m.contentList.Push(meta)

End Sub

Sub PosterScreenAddLikesItem()
	user = GetCurrentUser()
	meta = {}
	meta.ShortDescriptionLine1 = "Liked"
	meta.ShortDescriptionLine2 = user.username + "'s Liked"
	meta.NoContent = "Photos you like will appear here."
	
	if meta.instaRequest = invalid then
		meta.instaRequest = CreateInstaRequest(m.port)
		'meta.instaRequest.access_token = user.access_token
		meta.instaRequest.endpoint = "/users/self/media/liked"
		meta.instaRequest.StartGetToString()
		m.reqHash[Stri(meta.instaRequest.identity)] = meta
	end if
	
	meta.onselect = "slideshow"
	meta.key = "liked"
	m.contentList.Push(meta)

End Sub

Function PosterScreenGetSelectionRegKey()
	regKey = "selection_key"
	
	if m.posterType <> invalid 
		regKey = regKey + "_" + m.posterType
	end if

	return regKey
End Function

Sub PosterScreenSetFocusedListItem()
			
	selectionKey = RegRead(m.GetSelectionRegKey())
	selectionIndex = 0
	
	if selectionKey = invalid then
		if GetCurrentUser() <> invalid then
			selectionKey = "posts"
		else
			selectionKey = "popular"
		end if
	end if

	for each meta in m.contentList
		if selectionKey = meta.key then
			m.screen.SetFocusedListItem(selectionIndex)
			exit for
		end if
		selectionIndex = selectionIndex + 1
	next
	if selectionIndex = m.contentList.Count() then
		m.screen.SetFocusedListItem(0)
	end if
End Sub

Function PosterScreenRun()
	load = true
	globals = GetGlobals()
	loopcnt = 0
	
	

    while true
    	
    	if load then
    	
    		m.users = GetUsersList()

			m.Reset()
			
			if m.posterType <> invalid AND m.posterType = "popular-poster"
				print "poster type: " + m.posterType
				m.AddFeaturedUserItem({id:"25025320", full_name: "Instagram", username: "instagram"})
				m.AddInstaDailyItem()
				m.AddTrendingItem()
				m.AddCelebritiesItem()
				m.AddBeautyItem()
			else if m.posterType <> invalid AND m.posterType = "locations-poster"

				m.AddLocalItem()
				
				if false
					m.AddLocationItem({name:"Santa Monica Pier",id:"3001340"})
					m.AddLocationItem({name:"Times Square",id:"3001373"})
					m.AddLocationItem({name:"Central Park",id:"3001881"})
					m.AddLocationItem({name:"Disneyland",id:"3003018"})
					m.AddLocationItem({name:"Fountains of Bellagio",id:"55049"})
					
					m.AddLocationItem({name:"Eiffel Tower",id:"2593354"})
						
				else
					location = ReadLocation()
	
					m.locationsRequest = CreateInstaRequest(m.port)
					m.locationsRequest.AddQueryParam("lat", location.latitude)
					m.locationsRequest.AddQueryParam("lng", location.longitude)
					m.locationsRequest.AddQueryParam("distance", "5000")
					m.locationsRequest.endpoint = "/locations/search"
					m.locationsRequest.StartGetToString()
				end if

			else
				topLevelUserItemsVisible = false
				if m.users.Count() = 0 OR GetCurrentUser() <> invalid then
		    		m.AddPopularItem()
		    		if globals.features.locations
		    			m.AddLocationsItem()
		    		else
			    		m.AddLocalItem()
		    		end if
		    		m.AddSearchTagsItem()
					m.AddSearchUsersItem()
		    	else
		    		topLevelUserItemsVisible = true
		    	end if
		    	
		    	for each user in m.users
		    		m.AddUserItem(user, topLevelUserItemsVisible)
		    	next
		    	
		    	if GetCurrentUser() <> invalid 
					m.AddPostsItem()
					m.AddFeedItem()
					m.AddLikesItem()
		    	end if
		    	
	    		m.AddLinkUserItem()
	    		if globals.features.music
	    			m.AddAudioSettingsItem()
	    		end if
	    		
	    		m.AddAboutItem()
	    	
			end if
			
			m.RefreshContent()
			
			load = false
			m.SetFocusedListItem()
			
		end if
		
        msg = WaitForEvent(0, m.port)
        
        loopcnt = loopcnt + 1
		if msg <> invalid then
			if type(msg)="roUrlEvent" 
				if msg.GetInt() = 1 then
					json = msg.GetString()
					identity = msg.GetSourceIdentity()
					identityKey = Stri(identity)
					metaData = invalid
					print "identity: " + Stri(msg.GetSourceIdentity()) + ", responseCode: " + Stri(msg.GetResponseCode()) + ", reason:" + msg.GetFailureReason()
					
					
					if m.reqHash.DoesExist(identityKey)
						meta = m.reqHash[identityKey]
						meta.instaresponse = {}
						meta.instaresponse.responseCode = msg.GetResponseCode()
						meta.instaresponse.failureReason = msg.GetFailureReason()
						
						for each header in msg.GetResponseHeadersArray()
							for each key in header
								if key = "X-Ratelimit-Limit"
									meta.instaresponse.rateLimit = header[key] 
								end if
								if key = "X-Ratelimit-Remaining"
									meta.instaresponse.rateLimitRemaining = header[key] 
								end if
							end for
						next
						
						if meta.instaresponse.rateLimit <> invalid AND meta.instaresponse.rateLimitRemaining <> invalid
							if meta.instarequest <> invalid
								if meta.instarequest.access_token = invalid
									if globals.stats.clients[meta.instarequest.client_id] = invalid
										globals.stats.clients[meta.instarequest.client_id] = {}
									end if
									stats = globals.stats.clients[meta.instarequest.client_id]
									if stats <> invalid
										stats.rateLimit = meta.instaresponse.rateLimit
										stats.rateLimitRemaining = meta.instaresponse.rateLimitRemaining
									end if
								end if
							end if
						end if
						

						if meta.instaresponse.responseCode <> 200
							if meta.instarequest <> invalid AND meta.instarequest.url <> invalid
								errorMsg = "code: " + Stri(msg.GetResponseCode()) + ", reason:" + msg.GetFailureReason()
								LogErrorMessage(errorMsg, meta.instarequest.url)
								GaException(errorMsg).PostAsync()
							end if
						end if
						
						m.HandleInstagramMediaResponse(msg)
						m.reqHash.Delete(identityKey)						
					else if m.userInfoReqHash.DoesExist(Stri(msg.GetSourceIdentity()))
						load = m.HandleInstagramUserInfoResponse(msg)
					else if m.locationsRequest <> invalid AND m.locationsRequest.identity = identity
						parsed = ParseJson(json)
						print json
						if parsed <> invalid
							for each location in parsed.data
								m.AddLocationItem(location)
							next
							
							
							m.RefreshContent()
						else
							print "invalid locations search"
						end if
						
					else 
						print "ERROR: unhandled response"
					end if
				end if
			else if type(msg) = "roOneLineDialogEvent" 
					print "roOneLineDialogEvent"
					
			else if type(msg) = "roPosterScreenEvent" 

				if msg.isListItemSelected() then
					msgIndex = msg.getIndex()
					topMetaItem = m.contentList[msgIndex]
	
				 	print "topMetaItem.onselect = " + topMetaItem.onselect
				 	
		    		if topMetaItem.key <> invalid then
		    			RegWrite(m.GetSelectionRegKey(), topMetaItem.key)
		    		end if
	
					
	        		if topMetaItem.onselect = "slideshow" then
	        		
	        			if globals.saver
				    		if topMetaItem.key <> invalid then
				    			t = topMetaItem.ShortDescriptionLine1
				    			d = topMetaItem.ShortDescriptionLine2
				    			u = topMetaItem.instaRequest.url
				    			WriteScreenSaver("type", t)
				    			WriteScreenSaver("description", d)
				    		    WriteScreenSaver("url", u)
				    			
				    		    ShowScreenSaverSetDialog(d)
				    		    LogScreenSaverMessage(t + " : " + d, u)		
				    			m.screen.Close()
				    		end if
			    		
			    		else 
			    		
		        			if topMetaItem.parsedResponse = invalid then
		        				if topMetaItem.instaresponse <> invalid AND topMetaItem.instaresponse.responseCode <> 200
		        					
		        					ShowErrorDialog("Sorry, Instagram appears to be having a bad day. Please try again later.", topMetaItem.instaresponse.failureReason)
		        				else 
			        				m.busyDialog.SetTitle("Loading " + topMetaItem.ShortDescriptionLine1)
			        				m.busyDialog.ShowBusyAnimation()
			        				m.busyDialog.Show()
			        				m.busyShowing = topMetaItem.key
		        				end if
		        			else 
		        				if topMetaItem.parsedResponse.data.Count() > 0
		        				
		        					LogShowStartMessage("Starting show '" + topMetaItem.ShortDescriptionLine1 + "'", topMetaItem.instaRequest)
		        					GaEvent(type(msg), GetMsgAction(msg), topMetaItem.ShortDescriptionLine1)
		        				
				        			ss = CreateInstaShowFromParsedResponse(topMetaItem.parsedResponse)
				        			ss.nextEndpoint = topMetaItem.instaRequest.endpoint
				        			ss.nextEndpointParams = topMetaItem.instaRequest.qparams
				        			ss.screenName = topMetaItem.key + "-slideshow"
				        			ss.Run()

				        			if globals.features.music
				        				print "NOT PAUSING!!!"
				        				'PauseRadio()
		        					end if
		        					
				        			load = true
			        			else
			        				message = "This selection has no content"
			        				if topMetaItem <> invalid AND topMetaItem.NoContent <> invalid
			        					message = topMetaItem.NoContent
			        				end if
			        				ShowErrorDialog(message, "No Content")
			        			end if
		        			end if
	        			end if
	        		else if topMetaItem.onselect = "popular-poster" OR topMetaItem.onselect = "locations-poster"
	        			subPoster = CreatePosterScreen()
	        			subPoster.posterType = topMetaItem.onselect
	        			subPoster.topParsedResponse = topMetaItem.parsedResponse
	        			subPoster.topInstaRequest = topMetaItem.instaRequest
	        			subPoster.Show()
	        			subPoster.Run()
	        			
	        			load = true
	        		else if topMetaItem.onselect = "search-tags"
	        			searchScreen = CreateSearchScreen()
	        			
	        			if globals.saver
	        				searchScreen.screen.Show()
	        				m.screen.Close()
	        			end if

	        			ret = searchScreen.Run()
	        			
	        		else if topMetaItem.onselect = "search-users" then
	        			searchScreen = CreateSearchScreen()
	        			searchScreen.searchType = "users"
		        		if globals.saver
	        				searchScreen.screen.Show()
	        				m.screen.Close()
	        			end if
	        			
	        			searchScreen.Run()
	        			
	        		else if topMetaItem.onselect = "userposter" 
	        				
	        				SetCurrentUser(topMetaItem.user)
		        			
	        				subMenu = CreatePosterScreen()
	        				subMenu.Show()
	        				subMenu.Run()
	        				SetCurrentUser(invalid)
	        		else if topMetaItem.onselect = "regscreen" 
	        			regScreen = CreateRegistrationScreen()
	        			regScreen.Run()
	        			
	        			users = GetUsersList()
						if users.Count() = 1
							SetCurrentUser(users[0])
							m.user = GetCurrentUser()
						else
							SetCurrentUser(invalid)
							m.user = invalid
						end if
						
						SetBreadcrumb(m.screen)
	        				        			
	        			load = true	
	        		else if topMetaItem.onselect = "audioSettings" 
	        			globals.radio.asp.Run()
	        		else if topMetaItem.onselect = "aboutposter"
	        			aboutScreen = CreateAboutScreen()
	        			aboutScreen.Run()
	        		end if
	        	else if msg.IsListItemInfo()
	        		globals.radio.asp.Run()
				else if msg.isScreenClosed() then
					exit while
				end if
			end if
		else 
			'print "returned invalid"
		end if
	end while
	
	return 0
End Function


Function PosterScreenHandleInstagramUserInfoResponse(msg)
	json = msg.GetString()
	ret = false
	metaData = m.userInfoReqHash[Stri(msg.GetSourceIdentity())]
	if msg.GetResponseCode() = 200 then
		parsed = ParseJson(json)
		if parsed.meta <> invalid AND parsed.meta.code = 200 then
			if metaData.timespan <> invalid
				GaTiming("ig-user-req", metaData.key, metaData.timespan.TotalMilliseconds()).PostAsync()
			end if
		
			ret = RegWriteUser(parsed.data)	
		end if
	else if msg.GetResponseCode() = 400 then
		DeleteUser(metaData.user.id)
		print "User " + metaData.user.id + " has been removed"
		ret = true
	else
		print "Unxepected return code: " + metaData.key
	end if
	
	if ret then
		print "Something changed with a user, returning true"
	end if
	
	return ret
	
End Function

Sub PosterScreenHandleInstagramMediaResponse(msg)

	identity = msg.GetSourceIdentity()
	identityKey = Stri(identity)
	metaData = m.reqHash[identityKey]
	
	json = msg.GetString()
	parsedResponse = ParseJson(json)
	if parsedResponse <> invalid AND parsedResponse.meta.code = 200
	
		if metaData <> invalid 
		
			if metaData.timespan <> invalid
				GaTiming("ig-media-req", metaData.key, metaData.timespan.TotalMilliseconds()).PostAsync()
			end if
			
			metaData.parsedResponse = parsedResponse
							
			if m.busyShowing = metaData.key
				m.busyShowing = invalid
				print "Creating slideshow after busy indicator.."
				LogShowStartMessage("Starting show '" + metaData.ShortDescriptionLine1 + "'", metaData.instaRequest)
    			ss = CreateInstaShowFromParsedResponse(metaData.parsedResponse)
    			ss.nextEndpoint = metaData.instaRequest.endpoint
    			ss.Run()
			else 
				if metaData.onselect = "slideshow" OR metaData.key = "popular" OR metaData.key = "local"
					' SD = 223x200; HD = 300x300
				
					if parsedResponse.data.Count() > 0 then
						coverUrl = HackStripHttps(parsedResponse.data[0].images.thumbnail.url)
						metaData.HdPosterUrl = coverUrl
						metaData.SdPosterUrl = coverUrl	
						m.RefreshContent()
					else
						if metaData.key = "feed"
							metaData.HdPosterUrl = "pkg:/images/feed-hd.png"
							metaData.SdPosterUrl = "pkg:/images/feed-sd.png"
						else if  metaData.key = "liked"
							metaData.HdPosterUrl = "pkg:/images/heart-hd.png"
							metaData.SdPosterUrl = "pkg:/images/heart-sd.png"
						else
							metaData.HdPosterUrl = "pkg:/images/no-content-hd.png"
							metaData.SdPosterUrl = "pkg:/images/no-content-sd.png"
						end if
					end if
					
				end if
			end if
		else
			print "ERROR: metada invalid???"
		end if ' metaData invalid
	else
		print json
	end if ' meta.code = 200

End Sub


