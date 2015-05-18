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

Function CreateAudioSpringBoardScreen() As Object
	this = {
	
		screen: invalid,
		port: invalid,
		
		content: {},
		showing: false,
		can_skip: false,
		titleSearch: false,
		
		ResetButtons: AudioSpringboardResetButtons,
		StartItunesSearch: AudioSpringBoardStartItunesSearch,
		Refresh: AudioSpringBoardRefresh,
		ProcessEvents: AudioSpringboardProcessEvents,
		
		SetAudioContent: AudioSpringboardSetAudioContent,
		ClearAudioContent: AudioSprinboardClearAudioContent,
		
		ShowProgress: AudioSpringboardShowProgress,
		HideProgress: AudioSpringboardHideProgress,
		
		HandleChangeStation: AudioScreenHandleChangeStation,
		
		Run: AudioSpringboadRun
	}

	this.content = {}
	this.content.ContentType = "audio"


	return this
	
End Function

Sub AudioSpringBoardRefresh()
	print "audioScreen Refresh showing:" + tostr(m.showing)
	if m.showing
		m.screen.Show()
	end if
End Sub

Sub AudioSpringboardResetButtons()
	globals = GetGlobals()

	
	if m.screen <> invalid 
		m.screen.ClearButtons()
		
		m.screen.AllowUpdates(false)
		m.btnIndex = 0
		
		m.btnBack = 0
		m.btnPlayPause = 1
		m.btnSkip = 2
		m.btnChangeStation = 3
		m.btnOnOff = 4
		
		m.screen.AddButton(m.btnBack, "Back")
		
		if IsRadioEnabled()
			playPauseLabel = "Pause"
			if globals.radio.mode <> "play"
				playPauseLabel = "Play"
			end if
			
			m.screen.AddButton(m.btnPlayPause, playPauseLabel)
		
			if globals.radio.mode = "play" AND m.can_skip
				m.screen.AddButton(m.btnSkip, "Next Song")
			end if
		
			if globals.feedfm.changeStation
				m.screen.AddButton(m.btnChangeStation, "Change Station")
			end if
			
			m.screen.AddButton(m.btnOnOff, "Turn Off")
		else
			m.screen.AddButton(m.btnOnOff, "Turn On")
		end if
		
		m.screen.AllowUpdates(true)
	end if
	
End Sub

Sub AudioSpringboadRun()
	
	InitRadio()
	
	globals = GetGlobals()
	
	if globals.features.music
		m.screen = CreateObject("roSpringboardScreen")
		m.port = CreateObject("roMessagePort")
		m.screen.SetMessagePort(m.port)
		
		m.screen.SetCertificatesFile("common:/certs/ca-bundle.crt")
		m.screen.InitClientCertificates()
	
		m.screen.SetDescriptionStyle("audio")
		m.screen.SetStaticRatingEnabled(false)
		
		if globals.version >= 2.6 
			m.screen.UseStableFocus(true)
		end if
	
		m.screen.Show()
		GaScreenView("audio").PostAsync()
		
		m.StartItunesSearch()
		
		m.ResetButtons()
		
		m.screen.SetBreadcrumbEnabled(true)
			
		m.screen.SetBreadcrumbText("",GetRadioState())
		
		m.showing = true
		m.ProcessEvents()
	end if
	
End Sub

Sub AudioSpringBoardStartItunesSearch()
	if m.content <> invalid then
		if m.screen <> invalid
			m.content.SDPosterUrl = invalid
			m.content.HDPosterUrl = invalid
			m.screen.SetContent(m.content)
			m.screen.Show()
			
			if m.content.Album <> invalid
				m.iTunesRequest = CreateItunesRequest(m.port)
				print "Searching for album art for album '" + m.content.Album + "'"
				m.iTunesRequest.BuildAlbumRequestFromAlbumTitle(m.content.Album)
				m.iTunesRequest.StartGetToString()
			end if
		end if
	end if
End Sub


Sub AudioSpringboardSetAudioContent(artist, title, album, duration)


	m.content.Artist = artist
	m.content.Title = title
	m.content.Album = album
	'm.content.Length = duration
	
	m.titleSearch = false
	m.StartItunesSearch()
	m.Refresh()
	
End Sub

Sub AudioSprinboardClearAudioContent()
	m.content = {}
	m.content.ContentType = "audio"
	if m.screen <> invalid
		m.screen.SetProgressIndicatorEnabled(false)
		m.screen.SetContent(m.content)
		m.Refresh()
	end if
End Sub

Function AudioSpringboardProcessEvents()
	globals = GetGlobals()

	while true 

		msg = WaitForEvent(0, m.port)
		
	    if type(msg)="roUrlEvent" then
	    	identity = msg.GetSourceIdentity()
			if msg.GetInt() = 1 then
				json = msg.GetString()
				'print chr(10) + tostr(identity) + "::response: code=" + Stri(msg.GetResponseCode()) + chr(10) + json + chr(10)
				if m.iTunesRequest <> invalid AND m.iTunesRequest.identity = identity then
					if msg.GetResponseCode() = 200 then
						response = ParseJson(json)
						if response.results <> invalid
							if response.results.Count() = 0 
								print "iTunes returned no results"
							end if
							for each result in response.results
								if result.artistName <> invalid
									if result.artistName = m.content.Artist
										m.content.SDPosterUrl = result.artworkUrl100
										m.content.HDPosterUrl = result.artworkUrl100
										m.screen.SetContent(m.content)
										m.screen.Show()
										exit for
									end if
								end if
							next
						end if
						if m.content.SDPosterUrl = invalid
							
							if NOT m.titleSearch
								m.iTunesRequest = CreateItunesRequest(m.port)
								print "FAILED to lookup by albumname, now searching for album art for track '" + m.content.Title + "'"
								m.iTunesRequest.BuildAlbumRequestFromAlbumTitle(m.content.Title)
								m.iTunesRequest.StartGetToString()
								m.titleSearch = true
							else
								if response.results.Count() > 0
									print "WARNING: didn't find artistName match, trying first result"
									result = response.results[0]
									m.content.SDPosterUrl = result.artworkUrl100
									m.content.HDPosterUrl = result.artworkUrl100
									m.screen.SetContent(m.content)
									m.screen.Show()
								end if
							end if
							
						end if
					else
						print "ERROR: unextected return code: " + Stri(msg.GetResponseCode()) + ", reason:" + msg.GetFailureReason()
					end if
				end if
			else
				print "ERROR msg.GetInt() = " + tostr(msg.GetInt())
			end if
		else if type(msg) = "roSpringboardScreenEvent"
		
			if msg.isScreenClosed() then 
				m.showing = false
				return -1
			else if msg.isRemoteKeyPressed()
				ClearStillListening()
			else if msg.isButtonPressed() 
				index = msg.GetIndex()
				
				if index = m.btnBack then
					m.screen.Close()
					return 0
				else if index = m.btnPlayPause
					if globals.radio.mode = "play"
						PauseRadio()
					else
						PlayRadio()
					end if
					m.ResetButtons()
				else if index = m.btnSkip
					if globals.radio.song <> invalid then
						SkipRadio()
						'playSkipReq = CreateFeedFmRequest()
						'AddRadioRequest(playSkipReq)
						'playSkipReq.AsyncPlaySkip(globals.radio.song.feedFmPlayResp.play.id)
						'UpdateRadioDiag("skipping")
						'm.ClearAudioContent()
						
					end if
				else if index = m.btnChangeStation
					if m.HandleChangeStation()
						print "Station changed, radioState:" + GetRadioState() 
						if GetRadioState() = "playing"
							playSkipReq = CreateFeedFmRequest()
							AddRadioRequest(playSkipReq)
							playSkipReq.AsyncPlaySkip(globals.radio.song.feedFmPlayResp.play.id)
							UpdateRadioDiag("skipping")
						else if GetRadioState() = "ready"
							StartRadio()
						end if
					end if
					
				else if index = m.btnOnOff
					if IsRadioEnabled() then
						SetRadioEnabled(false)
						m.ClearAudioContent()
						' hack to give a mechanism for refreshing client id
						globals.feedfm.clientRequest = CreateFeedFmRequest()
						globals.feedfm.clientRequest.endpoint = "client"
						globals.feedfm.clientRequest.AsyncPostFromString("")
					else
						if globals.expired
							ShowUpgradeDialog()
						else
							SetRadioEnabled(true)
						end if
					end if 
					m.ResetButtons()
				end if ' buttons
			end if
		end if
	end while
End Function

Sub AudioSpringboardShowProgress(progress, max)
	if m.showing
		if m.screen <> invalid
			m.screen.SetProgressIndicatorEnabled(true)
			m.screen.SetProgressIndicator(progress,max)
		end if
	end if
End Sub

Sub AudioSpringboardHideProgress()
	if m.showing
		if m.screen <> invalid
			m.screen.SetProgressIndicatorEnabled(false)
		end if
	end if
End Sub

Function AudioScreenHandleChangeStation()
	
	ret = false
	
	globals = GetGlobals()
	
	diag = CreateObject("roMessageDialog")
	port = CreateObject("roMessagePort")
	
	diag.SetMessagePort(port)
	
	diag.SetTitle("Select Station")
	diag.EnableBackButton(true)
	
	btnIndex = 0
	diag.AddLeftButton(btnIndex, "Close")
	btnIndex = btnIndex + 1
	
	diag.AddButtonSeparator()
	btnIndex = btnIndex + 1
	
	btnMap = {}
	
	'diag.EnableOverlay(true)
	
	placementReq = CreateFeedFmRequest(invalid)
	placementReq.endpoint = "placement/" + globals.feedfm.placement
	
	placementReq.BuildXfer()
	placementMsg = HttpGetWithStatus(placementReq.xfer, "Getting station list...")
	
	identity = placementMsg.GetSourceIdentity()
	
	focusedIndex = 0
	
	if placementMsg.GetInt() = 1 then
		json = placementMsg.GetString()
		
		if identity = placementReq.identity

			print "feedFmReq placement response:" + json + chr(10)
			if placementMsg.GetResponseCode() = 200 
				feedFmResp = ParseJson(json)
				if feedFmResp.success then
					for each station in feedFmResp.stations
						btnIndexKey = Stri(btnIndex).Trim()
						btnMap[btnIndexKey] = station.id
						if station.id = globals.feedfm.station.Trim() 
							focusedIndex = btnIndex
						end if
						'print "btnMap[" + btnIndexKey + "] = " + station.id + " (" + station.name + ")"
						diag.AddButton(btnIndex, station.name)
						btnIndex = btnIndex + 1
					next
				end if
			end if ' retCode = 200
		end if ' idendity match
	end if ' GetInt() = 1
	
	print "SetFocusedMenuItem: " + Stri(focusedIndex)
	diag.SetFocusedMenuItem(focusedIndex)
	
'	btnStationHash = {}
	
	diag.Show()
	
	while true 

		msg = WaitForEvent(0, port)
		
	    if type(msg) = "roUrlEvent" then
	    	print "HERE"
		else if type(msg) = "roMessageDialogEvent"
			print "roMessageDialogEvent"
			if msg.isScreenClosed() 
				exit while
			else if msg.isButtonPressed()
				if msg.GetIndex() > 0
					stationId = btnMap[Stri(msg.GetIndex()).Trim()]
					ret = SetFeedFmStation(stationId)
				end if
				diag.Close()
				exit while
			end if
		end if ' events
		

	end while
		
	return ret
	
End Function