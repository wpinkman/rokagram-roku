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
Sub CreateRadioPlayer()
	
	globals = GetGlobals()
	
	'globals.radio.mode = "stopped"
	globals.radio.mode = "play"
	globals.radio.song = invalid
	globals.radio.started = false

	globals.radio.btn_close = 0
	globals.radio.btn_skip = 1
	globals.radio.btn_toggle = 2
	globals.radio.diag_showing = false
	globals.radio.error_message = invalid
	
	globals.radio.audio_cutoff = 60*5
	globals.radio.user_idle = false

	globals.radio.player = CreateObject("roAudioPlayer")
	globals.radio.player.SetMessagePort(GetGlobalPort())
	globals.radio.player.SetCertificatesFile("common:/certs/ca-bundle.crt")
	globals.radio.player.InitClientCertificates()

	globals.radio.timespan = CreateObject("roTimespan")
	
	globals.radio.user_idle_paused = false
	
End Sub

Sub InitRadio()
	
	globals = GetGlobals()
	
	if GetFeedFmClientId() <> invalid AND globals.radio.player <> invalid then
		
		if IsRadioEnabled() then
			if globals.radio.started = false
				StartRadio()
			end if
		end if
	end if
	
End Sub

Sub StartRadio()
	globals = GetGlobals()
	
	if globals.features.music
		if IsRadioEnabled() 
			playReq = CreateFeedFmRequest()
			
			AddRadioRequest(playReq)
			playReq.AsyncPlay()
			print "STARTING RADIO"
			UpdateRadioDiag("starting")
			globals.radio.started = true
		end if
	end if
	
End Sub


Sub PlayRadio()
	print "PlayRadio"
	globals = GetGlobals()
	if IsRadioEnabled() then
		if globals.radio.mode = "pause" then
			globals.radio.player.Resume()
			print "PLAYER.RESUME"
			
			if globals.radio.user_idle_paused
				print "sending start req.."
				playStartReq = CreateFeedFmRequest()
				AddRadioRequest(playStartReq)
				playStartReq.AsyncPlayStart(globals.radio.song.feedFmPlayResp.play.id)
				globals.radio.user_idle_paused = false
			end if
			
		else if globals.radio.mode <> "play"
			if globals.radio.player <> invalid then
				globals.radio.player.Play()
			end if
		end if
		
		globals.radio.mode = "play"
	end if
		
End Sub

Sub PauseRadio()
	if IsRadioEnabled() then
	
		globals = GetGlobals()
		
		if globals.radio.mode = "play" then
			if globals.radio.player <> invalid
				globals.radio.player.Pause()
			end if
		end if
		
		globals.radio.mode = "pause"
			
	end if
End Sub

Sub StopRadio()
	if IsRadioEnabled() then
	
		globals = GetGlobals()
		
		if globals.radio.player <> invalid
			globals.radio.player.Stop()
		end if
					
	end if
End Sub

Sub SkipRadio()
	globals = GetGlobals()
	if globals.radio.player <> invalid
		globals.radio.player.Stop()
	end if
	playSkipReq = CreateFeedFmRequest()
	AddRadioRequest(playSkipReq)
	playSkipReq.AsyncPlaySkip(globals.radio.song.feedFmPlayResp.play.id)
	UpdateRadioDiag("skipping")
End Sub

Sub MarkRadioTimestamp()
	globals = GetGlobals()
	if globals.radio <> invalid AND globals.radio.timespan <> invalid
	
		globals.radio.timespan.Mark()
		
		if globals.radio.user_idle_paused
			PlayRadio()
		end if
		
		globals.radio.user_idle = false
	end if
End Sub

Function StillListeningRadio()
	ret = false
	globals = GetGlobals()
	if globals.radio <> invalid AND globals.radio.user_idle <> invalid then
		ret = globals.radio.user_idle
	end if
	
	return ret
End Function

Sub ClearStillListening()
	globals = GetGlobals()
	if StillListeningRadio() then
		StartRadio()
		globals.radio.user_idle = false
	end if
End Sub

Sub AddRadioRequest(request)
	GetGlobals().radio.reqHash[Stri(request.identity)] = request
End Sub

Sub SetRadioState(state)
	GetGlobals().radio.state = state
End Sub

Function GetRadioState()
	
	return GetGlobals().radio.state
End Function

Function IsRadioEnabled()
	globals = GetGlobals()
	
	ret = true
	if globals.features.music
		regVal = RegRead("radio", globals.constants.sections.default)
		if regVal <> invalid then
			if regVal = "false" then
				ret = false
			end if
		end if
	else
		ret = false
	end if
	
	return ret
End Function

Function SetRadioEnabled(enbl As Boolean)
	globals = GetGlobals()
	'RegWriteBoolean("radio", enbl, globals.sections.default)
	if enbl then
		print "Rokugram Radio ENABLED"
		RegWrite("radio", "true", globals.constants.sections.default)
		StartRadio()
	else
		print "Rokugram Radio DISABLED"
		RegWrite("radio", "false", globals.constants.sections.default)
		UpdateRadioDiag("off")
		'm.screen.SetBreadcrumbText("",GetRadioState())
		
		if globals.features.music
	
			if globals.radio <> invalid then
				if globals.radio.song <> invalid then
					if globals.radio.song.feedFmPlayResp <> invalid then
						globals.radio.song.feedFmPlayResp = invalid
					end if
				end if
				globals.radio.player.Stop()
			end if
		end if
	end if
	
End Function

Function HandleFeedFmResponse(msg)
	ret = false
	
	if msg.GetInt() = 1 then
	
		globals = GetGlobals()
		identity = msg.GetSourceIdentity()
		identityKey = Stri(identity)
	
		if globals.radio.reqHash.DoesExist(identityKey) then
	
			feedFmReq = globals.radio.reqHash[identityKey]
			ret = true
			globals.radio.reqHash.Delete(identityKey)
			json = msg.GetString()
			print "feedFmReq " + feedFmReq.reqType +  " response:" + json + chr(10)
			if msg.GetResponseCode() = 200 then
				feedFmPlayResp = ParseJson(json)
				if feedFmPlayResp.success then
				
					GaEvent("radio", feedFmReq.reqType).SetNonInteractive().PostAsync()

					if feedFmReq.reqType = "play" then
						if feedFmPlayResp.play <> invalid then
							if feedFmPlayResp.play.audio_file <> invalid then
								if feedFmPlayResp.play.audio_file.track <> invalid AND feedFmPlayResp.play.audio_file.artist <> invalid then
									globals.radio.trackmsg = feedFmPlayResp.play.audio_file.track.title + " by " + feedFmPlayResp.play.audio_file.artist.name
									
									af = feedFmPlayResp.play.audio_file
									globals.radio.asp.SetAudioContent(af.artist.name, af.track.title, af.release.title, af.duration_in_seconds)

								end if
								
								song = {}
								song.Url = af.url
								song.feedFmPlayResp = feedFmPlayResp
								
								codec = feedFmPlayResp.play.audio_file.codec
								
								if codec = "original"
									song.StreamFormat = "mp4"
								else if codec <> "mp3"
									print "WARNING: not sure about codec: " + codec
								end if
								
								contentList = []
								contentList.Push(song)
								globals.radio.song = song
								globals.radio.player.SetContentList(contentList)
								if globals.radio.mode = "play" then
									globals.radio.player.Play()
								end if
								
								UpdateRadioDiag("ready")
								
								
							end if   
						end if
					else if feedFmReq.reqType = "playskip" then
						StartRadio()
					else if feedFmReq.reqType = "playcomplete" OR feedFmReq.reqType = "playinvalidate"
						LogRadioMessage(feedFmReq.reqType + ", elapsed:" + Stri(globals.radio.timespan.TotalSeconds()) + " of " + Stri(globals.radio.audio_cutoff))
						globals.radio.user_idle = globals.radio.timespan.TotalSeconds() > globals.radio.audio_cutoff
						print "Setting user_idle to " + tostr(globals.radio.user_idle) + " and starting next song"

						StartRadio()
					else if feedFmReq.reqType = "playstart" then
						msg = "started: " + globals.radio.trackmsg
					
						if globals.radio.trackmsg <> invalid
							LogFeedfmStartMessage(globals.radio.trackmsg)
						end if
					
						if globals.radio.asp.can_skip <> feedFmPlayResp.can_skip
							
							globals.radio.asp.can_skip = feedFmPlayResp.can_skip
							globals.radio.asp.ResetButtons()
							
						end if
					else
						print "??? was a response to: " + feedFmReq.endpoint
					end if
				else
					if feedFmPlayResp.error <> invalid AND feedFmPlayResp.error.message <> invalid then
						globals.radio.error_message = feedFmPlayResp.error.message
						LogRadioMessage(globals.radio.error_message)
						print "ERROR:" + chr(10) + "response:" + json + chr(10)
					end if
					UpdateRadioDiag("error")
				end if
			else
				errormsg = "Unexpeced return code: " + Stri(msg.GetResponseCode()) + ", reason:" + msg.GetFailureReason()
				print errormsg
				LogRadioMessage(errormsg)
				UpdateRadioDiag("error")
			end if
		end if
	end if
	return ret
End Function

Sub HandleAudioPlayerEvent(msg)
	message = msg.GetMessage()
	index = msg.GetIndex()
	globals = GetGlobals()
	
	progressMessage = false
	if msg.isStatusMessage()
		if message = "startup progress"
			progressMessage = true
		end if
	end if
	
	if NOT progressMessage
		globals.radio.asp.HideProgress()
	end if
				
	if msg.isRequestSucceeded() then
		print "isRequestSucceeded(), index:" + Stri(index)
		print "Finished playing " + Stri(index) + ", feed.fm id: " + globals.radio.song.feedFmPlayResp.play.id
		playCompleteReq = CreateFeedFmRequest()
		AddRadioRequest(playCompleteReq)
		playCompleteReq.AsyncPlayComplete(globals.radio.song.feedFmPlayResp.play.id)
		
	else if msg.isRequestFailed() then
		print "isRequestFailed()" + msg.GetMessage()
		if globals.radio.song <> invalid then
			playInvalidateReq = CreateFeedFmRequest()
			AddRadioRequest(playInvalidateReq)
			playInvalidateReq.AsyncPlayInvalidate(globals.radio.song.feedFmPlayResp.play.id)
		end if
	else if msg.isFullResult() 
		print "isFullResult()"
	else if msg.isPartialResult() 
		print "isPartialResult()"
	else if msg.isPaused() 
		UpdateRadioDiag("paused")
	else if msg.isResumed() 
		UpdateRadioDiag("playing")
	else if msg.isStatusMessage() 
		'print message + " %" + Stri(index) 
		if message = "startup progress" then
			SetRadioState("buffering") 
			globals.radio.asp.ShowProgress(index, 1000)
		else if message = "start of play" then
			if globals.radio.song <> invalid
				if globals.radio.song.feedFmPlayResp <> invalid AND globals.radio.song.feedFmPlayResp.play <> invalid AND globals.radio.song.feedFmPlayResp.play.id <> invalid
					print "Started playing " + Stri(index) + ", feed.fm id: " + globals.radio.song.feedFmPlayResp.play.id
				end if
			end if
			
			
			if globals.radio.user_idle
				PauseRadio()
				globals.radio.user_idle_paused = true
			else
				UpdateRadioDiag("playing")
				
				playStartReq = CreateFeedFmRequest()
				AddRadioRequest(playStartReq)
				playStartReq.AsyncPlayStart(globals.radio.song.feedFmPlayResp.play.id)
			end if
		else
			print "isStatusMessage() : " + msg.GetMessage()
		end if
	end if
						    
End Sub

Sub HandleMessageDialogEvent(msg)
	globals = GetGlobals()
	if msg.isButtonPressed() then
		index = msg.GetIndex()
		
		if index = globals.radio.btn_close then
			HideRadioDiag()
		else if index = globals.radio.btn_skip then
			if globals.radio.song <> invalid then
				playSkipReq = CreateFeedFmRequest()
				AddRadioRequest(playSkipReq)
				playSkipReq.AsyncPlaySkip(globals.radio.song.feedFmPlayResp.play.id)
				UpdateRadioDiag("skipping")
			end if
		
		else if index = globals.radio.btn_toggle then
			SetRadioEnabled(NOT IsRadioEnabled())
			if IsRadioEnabled() then
				StartRadio()
			else
				SetRadioState("off")
				globals.radio.asp.ClearAudioContent()
				
'				globals.feedfm.clientRequest = CreateFeedFmRequest()
'				globals.feedfm.clientRequest.endpoint = "client"
'				print "POSTING to client for id, identity:" + Stri(globals.feedfm.clientRequest.identity) 
'				globals.feedfm.clientRequest.AsyncPostFromString("")

				if globals.radio <> invalid then
					if globals.radio.song <> invalid then
						if globals.radio.song.feedFmPlayResp <> invalid then
							globals.radio.song.feedFmPlayResp = invalid
						end if
					end if
					globals.radio.player.Stop()
				end if
				HideRadioDiag()
			end if
		end if
		
	else if msg.isScreenClosed() then
		'globals.radio.diag_showing = false
	end if

End Sub

Function NewRadioDiag()

	globals = GetGlobals()
	
	messageDiag = CreateObject("roMessageDialog")
	messageDiag.SetMessagePort(GetGlobalPort())
	messageDiag.SetTitle("Rokagram Radio")
	messageDiag.EnableBackButton(true)
	messageDiag.EnableOverlay(true)
	messageDiag.AddButton(globals.radio.btn_close, "Close")
	
	if IsRadioEnabled() then
		messageDiag.AddButton(globals.radio.btn_skip, "Skip")
		messageDiag.AddButton(globals.radio.btn_toggle, "Turn Off")
	else
		messageDiag.AddButton(globals.radio.btn_toggle, "Turn On")
	end if
	return messageDiag

End Function

Sub ShowRadioDiag()
	GetGlobals().radio.diag_showing = true
	UpdateRadioDiag()
End Sub

Sub UpdateRadioSpringboard(newState = invalid)
	if globals.radio.diag_showing
	end if
End Sub

Sub UpdateRadioDiag(newState = invalid)

	globals = GetGlobals()
	statechange = true
	
	if newState <> invalid then
		if newState = GetRadioState() then
			statechange = false
		else
			SetRadioState(newState)
		end if
	end if
					
	if statechange OR GetRadioState() <> "off" then
		print "Updating audio diag: " + GetRadioState() + ", statechange:" + tostr(statechange)
	end if
	
	if globals.radio.asp.showing AND statechange
		
		globals.radio.asp.screen.SetBreadcrumbEnabled(true)
		
		globals.radio.asp.screen.SetBreadcrumbText("",GetRadioState())
		globals.radio.asp.screen.Show()
		globals.radio.asp.ResetButtons()
	end if

	
	if globals.radio.diag_showing AND statechange then
		
		if globals.radio.dialog <> invalid then 
			globals.radio.dialog.Close()
		end if
		
		globals.radio.dialog = NewRadioDiag()
		
		
		if GetRadioState() = "buffering" OR GetRadioState() = "starting" OR GetRadioState() = "skipping" then
			globals.radio.dialog.ShowBusyAnimation()
		else if GetRadioState() = "error" then
			if globals.radio.error_message = invalid then
				errorMsg = "An error occurred"
			else 
				errorMsg = globals.radio.error_message
			end if
			globals.radio.dialog.SetText(errorMsg)
		else if GetRadioState() = "off" then
			globals.radio.dialog.SetText("Radio is off")
		else
			globals = GetGlobals()
			if globals.radio.song <> invalid AND globals.radio.song.feedFmPlayResp <> invalid then
				if globals.radio.song.feedFmPlayResp.play.audio_file.track <> invalid AND globals.radio.song.feedFmPlayResp.play.audio_file.artist <> invalid then
					if globals.radio.dialog <> invalid then
						globals.radio.dialog.SetText("Track: " + globals.radio.song.feedFmPlayResp.play.audio_file.track.title)
						globals.radio.dialog.SetText("Artist: " + globals.radio.song.feedFmPlayResp.play.audio_file.artist.name)
					end if
				end if
			end if
		end if
		globals.radio.dialog.Show()
	end if
End Sub

Sub HideRadioDiag()
	globals = GetGlobals()
	if globals.radio.dialog <> invalid then
		globals.radio.dialog.Close()
		globals.radio.dialog = invalid
	end if
	globals.radio.diag_showing = false
End Sub

