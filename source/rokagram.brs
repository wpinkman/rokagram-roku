' *********************************************************
' *********************************************************
' **
' **  Rokagram Channel
' **
' **  A. Waddell, February 2014
' **
' **  Copyright (c) 2014 Fugue State, Inc., All Rights Reserved.
' **
' *********************************************************
' *********************************************************

Library "v30/bslCore.brs"

Sub Init()

	InitGlobals()
	SetTheme()

End Sub


Sub Main()

	Init()
	
	globals = GetGlobals()
	
	facad = invalid
	if GetGlobals().wipeonexit
		facade = CreateFacade()
		facade.Show()
	end if
	
	if globals.saverTest
		RunScreenSaverSettings()
		RunScreenSaver()
	else if globals.saver2Test
		RunReelSaver()
	else
		
		LogStartupMessage("Version: " + globals.cversion)

		InitNetworkCalls()
		
		screen = CreatePosterScreen()
		screen.Show()
				
		WaitIfFirstTime()
		
		shouldRun = true
		
		if globals.trial
			if globals.usa
				shouldRun = HandleTrial()
			else
				ShowUpgradeScreen(true)
			end if
		end if
	
		if shouldRun
			screen.Run()
		end if
		
		bye = "EXITING... Bye!"
		LogExitingMessage(bye)
		print bye
	end if
	
	if GetGlobals().wipeonexit
		WipeRegistry()
		facade.Close()
	end if
	
End Sub

Sub RunScreenSaver()

	Init()
	AutoLogin()
	
	GetGlobals().saver = true
	
	saver = CreateScreenSaver()
	saver.Run()

End Sub

Sub RunScreenSaverSettings()

	Init()
	AutoLogin()

	GetGlobals().saver = true
	
	saver = CreateScreenSaver()
	saver.RunSettings()

End Sub

Function HandleTrial()

	shouldRun = true
	
	globals = GetGlobals()
	
	freeDays = globals.trialDays
	
	daysElapsed% = GetTrialDaysElapsed()
	
	daysLeft = freeDays - daysElapsed%
	daysLeftStr = Stri(daysLeft)
	
	days = "days"
	if (freeDays - daysElapsed%) = 1
		days = "day"
	end if
	
	title = "Trial Version"
	message = ""
	if daysLeft > 0
		message = message + "You have " + daysLeftStr + " " + days + " left to try Rokagram for free."
	else
		message = message + "Your trial period has expired."
	end if
	
	LogStoreMessage(message)
	
	trialElapsed = false
	
	globals.expired = RegReadBoolean("expired", globals.constants.sections.default)
	
	ret = 0
	
	if NOT globals.expired
		if NOT (daysLeft > 0)
			globals.expired = true
			RegWriteBoolean("expired", true, globals.constants.sections.default)
			SetRadioEnabled(false)
			ret = ShowDialog2Buttons(title, message, "Upgrade to full version", "Keep using free version")
		else 
			ret = ShowDialog2Buttons(title, message, "Upgrade to full version", "Let me try it first")
		end if


		if ret = 0
			ShowUpgradeScreen(NOT shouldRun)
		else
			if globals.expired
				LogStoreMessage("Keep using free clicked")
			else
				LogStoreMessage("Try it button clicked")
			end if
		end if
	end if
	
	return shouldRun
	
End Function


Function RegistrationDone()
	ret = false
	
	globals = GetGlobals()
	
	if globals.rokaResponse
		if globals.features.music
			if GetFeedFmClientId() <> invalid
				ret = true
			end if
		else
			ret = true		
		end if
	end if
	
	return ret
	
End Function

Sub WaitIfFirstTime()
		
	globals = GetGlobals()
	
    port = CreateObject("roMessagePort")
    dialog = CreateObject("roOneLineDialog")
    dialog.SetMessagePort(port)

    dialog.SetTitle("Please wait ...")
    dialog.ShowBusyAnimation()
    dialog.Show()
    
    timespan = CreateObject("roTimeSpan")
    timespan.Mark()
    
    while true
    	msg = WaitForEvent(1000, dialog.GetMessagePort())

    	if msg = invalid
    		elapsed = timespan.TotalSeconds()
    		print "total seconds: " + Stri(elapsed)
    		if elapsed > 14
    			dialog.Close()
    			GaException("registration timeout").PostAsync()
    		else
    			if RegistrationDone()
    				dialog.Close()
    				GaTiming("rg-reg-req", "loadtime", timespan.TotalMilliseconds()).PostAsync()
    			end if
    		end if
    	else
		    if type(msg) = "roOneLineDialogEvent"
		        if msg.isScreenClosed()
		            exit while
		        end if
		    endif
	    end if
    
    end while
		
	
End Sub

Sub InitNetworkCalls()

	globals = GetGlobals()
	if globals.rokagram.startupRequest = invalid then
		globals.rokagram.startupRequest = CreateRokaRequest(GetGlobalPort())
		url = GetServer() + "/api/device"
		globals.rokagram.startupRequest.xfer.SetUrl(url)
		print "STARTUP: Posting rokareq " + url + "(" + Stri(globals.rokagram.startupRequest.identity) + ")"
		if globals.localhost
			ShowReg()
		end if
		globals.rokagram.startupRequest.xfer.AsyncPostFromString(RegToXml())
		
	end if
	
	if globals.features.music
		if GetFeedFmClientId() = invalid 
			globals.feedfm.clientRequest = CreateFeedFmRequest()
			globals.feedfm.clientRequest.endpoint = "client"
			print "POSTING to client for id, identity:" + Stri(globals.feedfm.clientRequest.identity) 
			globals.feedfm.clientRequest.AsyncPostFromString("")
		end if
		if globals.radio.player = invalid
			print "Creating radio player"
			CreateRadioPlayer()
		end if
	end if

End Sub

Function CreateFacade()

	canvas = CreateObject("roImageCanvas")
	port = CreateObject("roMessagePort")
	canvas.SetMessagePort(port)
	'Set opaque background
	canvas.SetLayer(0, {Color:"#FF000000", CompositionMode:"Source"})
	
	return canvas
End Function

Function WaitForEvent(timeout, port)

	globals = GetGlobals()
	
	ret = invalid
	timespan = CreateObject("roTimeSpan")
	
	while ret = invalid AND (timeout = 0 OR timespan.TotalMilliseconds() < timeout)
		ret = wait(100, port)
		
		gmsg = 0
		'print "START clearing down global events"
		while gmsg <> invalid
			gmsg = wait(100, GetGlobalPort())
			if type(gmsg)="roUrlEvent" then
				identity = gmsg.GetSourceIdentity()
				identityKey = Stri(identity)
				if globals.feedfm.clientRequest <> invalid AND globals.feedfm.clientRequest.identity = identity then
					HandleFeedFmClientResponse(gmsg)
				else if globals.rokagram.startupRequest <> invalid AND globals.rokagram.startupRequest.identity = identity then
					globals.rokaResponse = true
					HandleRokaResponse(gmsg)
				else if globals.logging.reqHash.DoesExist(identityKey)
					globals.logging.reqHash.Delete(identityKey)
					globals.logging.reqCount = globals.logging.reqCount - 1
				else if globals.ga.reqHash.DoesExist(identityKey)
					globals.ga.reqHash.Delete(identityKey)
					globals.ga.reqCount = globals.ga.reqCount - 1
				else
					if NOT HandleFeedFmResponse(gmsg) then
						print "unhandled urlevent identity:" + tostr(identity) + ", responseCode:" + tostr(gmsg.GetResponseCode())
						print "BODY:" + gmsg.GetString()
						ret = gmsg
						exit while
					end if
				end if
			else if type(gmsg)="roAudioPlayerEvent" then
				if IsRadioEnabled() 
					HandleAudioPlayerEvent(gmsg)
				end if
			else if type(gmsg)="roMessageDialogEvent" then
				HandleMessageDialogEvent(gmsg)
			end if
		end while
		
	end while
		
	if ret <> invalid 
		shouldResume = false
		retType = type(ret)
		
		if NOT shouldResume
			shouldResume = (retType = "roSlideShowEvent" AND ret.isRemoteKeyPressed())
		end if
		
		if NOT shouldResume
			shouldResume = (retType = "roPosterScreenEvent" AND (ret.isListItemSelected() OR ret.isRemoteKeyPressed() OR ret.isListItemFocused() OR ret.IsListItemInfo()))
		end if
		
			
		if shouldResume
		'		ClearStillListening()
			'PlayRadio()
			MarkRadioTimestamp()
		end if
	end if
		
	return ret

End Function

Sub HandleRokaResponse(msg)

	globals = GetGlobals()
	json = msg.GetString()
	
	print chr(10) + "Rokagram response:" + json + chr(10)
	
	if msg.GetResponseCode() = 200 then
		parsedRokaResponse = ParseJson(json)
		if parsedRokaResponse.location <> invalid then
			if WriteLocation(parsedRokaResponse.location) then
				print "Change of location"
			end if
			
			if parsedRokaResponse.feedfm <> invalid
				rspfm = parsedRokaResponse.feedfm
				glbfm = globals.feedfm
				
				key = "changeStation"
				
				if rspfm[key] <> invalid AND rspfm[key] <> glbfm[key]
					print "feedfm." + key + " is now " + tostr(rspfm[key])
					glbfm[key] = rspfm[key]
					RegWrite(key, tostr(glbfm[key]), globals.constants.sections.feedfm)
				
				end if
				
				if rspfm.basicAuth <> invalid
					print "setting feedfm basic auth to " + rspfm.basicAuth 
					RegWrite("basicAuth", rspfm.basicAuth, globals.constants.sections.feedfm)
					globals.feedfm.basicAuth = rspfm.basicAuth
				end if
				
			end if
			
			if parsedRokaResponse.instagram <> invalid
				if parsedRokaResponse.instagram.client_id <> invalid
					reg_client_id = RegRead("client_id",  globals.constants.sections.instagram)
					if reg_client_id = invalid OR reg_client_id <> parsedRokaResponse.instagram.client_id
						print "saving to reg client id: " + parsedRokaResponse.instagram.client_id
						RegWrite("client_id", parsedRokaResponse.instagram.client_id, globals.constants.sections.instagram)
					end if
					if parsedRokaResponse.instagram.client_id <> globals.instagram.client_id
						print "upating client id: " + parsedRokaResponse.instagram.client_id
						globals.instagram.client_id = parsedRokaResponse.instagram.client_id
					end if
				end if
			end if
			
			if parsedRokaResponse.regmods <> invalid
				
				for each regmod in parsedRokaResponse.regmods
					if regmod.action = "write"
						LogDebugMessage("RegWrite('" + regmod.key + "','" + regmod.value + "','" + regmod.section + "')")
						RegWrite(regmod.key, regmod.value, regmod.section)
					end if
					if regmod.action = "delete"
						LogDebugMessage("RegDelete('" + regmod.key + "','" + regmod.section + "')")
						RegDelete(regmod.key, regmod.section)
					end if
					if regmod.action = "deleteUser"
						LogDebugMessage("DeleteUser('" + regmod.key + "')")
						DeleteUser(regmod.key)
					end if

					if regmod.action = "nuke"
						LogDebugMessage("** WipeRegistry **")
						WipeRegistry()
					end if

				next
				
				if parsedRokaResponse.regmods.Count() > 0
					LogDebugMessage(tostr(parsedRokaResponse.regmods.Count()) + " registry mods total")
				end if
			
			end if
			
			
			sslPatchDomain = RegRead("sslPatchDomain", globals.constants.sections.default)
			if parsedRokaResponse.sslPatchDomain <> invalid
				globals.sslPatchDomain = parsedRokaResponse.sslPatchDomain
				RegWrite("sslPatchDomain", globals.sslPatchDomain, globals.constants.sections.default)
			end if
			
			WriteConfigSection(parsedRokaResponse.ga, globals.ga, globals.constants.sections.ga)
			
			if type(parsedRokaResponse.instadaily) = "roArray"
				if parsedRokaResponse.instadaily.Count() = 7
					for i = 0 to 6
						globals.instadaily[i] = parsedRokaResponse.instadaily[i]
					end for
				end if
			end if
			
			
			if globals.trial
				if parsedRokaResponse.resetTrial <> invalid AND parsedRokaResponse.resetTrial
					dateTime = CreateObject("roDateTime")
					secondsNow% = dateTime.AsSeconds()
					RegWrite(globals.constants.keys.trial_start, Stri(secondsNow%).Trim(), globals.constants.sections.default)
					LogDebugMessage("resetting trial")
	
				end if
				if parsedRokaResponse.rescindTrial <> invalid AND parsedRokaResponse.rescindTrial
					dateTime = CreateObject("roDateTime")
					secondsNow% = dateTime.AsSeconds()
					secondsRescind% = secondsNow% - (86400*30)
					RegWrite(globals.constants.keys.trial_start, Stri(secondsRescind%).Trim(), globals.constants.sections.default)
					LogDebugMessage("**RESCINDING TRIAL**")
	
				end if
				
				if parsedRokaResponse.trialDays <> invalid
					globals.trialDays = parsedRokaResponse.trialDays 
					RegWrite("trialDays", Stri(globals.trialDays).Trim(), globals.constants.sections.default)
				end if
				
			end if
		end if
	end if

End Sub


' ******************************************************
' Setup theme for the application 
' ******************************************************
Sub SetTheme()

	globals = GetGlobals()
	
	if NOT globals.appInit
	    app = CreateObject("roAppManager")
	    theme = CreateObject("roAssociativeArray")
	
	    theme.OverhangOffsetSD_X = "20"
	    theme.OverhangOffsetSD_Y = "20"
	    theme.OverhangLogoSD  = "pkg:/images/RokagramLogoSD.png"
	    theme.OverhangSliceSD = "pkg:/images/Rokagram4x110.jpg"
	
		theme.OverhangOffsetHD_X = "37"
		theme.OverhangOffsetHD_Y = "37"
	    theme.OverhangLogoHD  = "pkg:/images/camera-only.png"
	    theme.OverhangSliceHD = "pkg:/images/Home_Overhang_BackgroundSlice_HD.jpg"
	
	    theme.OverhangSecondaryLogoHD = "pkg:/images/rokagram-logo-text-only.png"
	    theme.OverhangSecondaryLogoOffsetHD_X = "100"
	    theme.OverhangSecondaryLogoOffsetHD_Y = "45"
	    	
		 theme.BreadcrumbTextLeft = "#FFFFFF"
		 theme.BreadcrumbDelimiter = "#FFFFFF"
		 theme.BreadcrumbTextRight = "#000000"
	   
	    app.SetTheme(theme)
	    
		globals.appInit = true
	else
		print "WARNING: Skipping SetTheme"
	end if

End Sub


