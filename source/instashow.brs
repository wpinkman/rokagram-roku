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

Function CreateInstaShow(endpoint) As Object
	this = CreateInstaShowCommon()
	this.currentUser = GetCurrentUser()
	this.endpoint = endpoint
	
	return this
	
End Function

Function CreateInstaShowFromParsedResponse(parsedResponse) As Object
	this = CreateInstaShowCommon()
	this.parsedResponse = parsedResponse
	
	return this

End Function

Function CreateInstaShowCommon()
	this = {
		
		ss: CreateObject("roSlideShow"),
		xfer: CreateObject("roUrlTransfer"),
		busyDialog: invalid,
		port: CreateObject("roMessagePort"),
		
		screenName: "slideshow",
		
		' state
		playbackPosition: 0,
		paused: false,
		overlayVisible: false,
		buttons: invalid,
		maxSlides: 100,
		buttonsShowing: false,
		
		btnToggleLike: 0,
		btnComment: 1,
		btnToggleFollow: 2,
		btnToggleCaptions: 3,
		btnClose: 4,
		btnPlayVideo: 5,
		
		textOverlayVisible: true,
		remoteOkPressed: false,
		
		contentArray: invalid,
		contentItem: invalid
		
		currentUser: invalid,
		endpoint: invalid,
		parsedResponse: invalid,
		
		nextEndpoint: invalid,
		nextInstaRequest: invalid,
		nextParsedResposne: invalid,
		nextUrl: invalid,
		startNextXferIndex: 3,
		
		overlayDisableKey: "overlayDisable",
		
		shouldClose: false,
		
		SetNext: InstaShowSetNext,
		SetPrevious: InstaShowSetPrevious,
		
		AddRequest: InstaShowAddRequest,
		
		ProcessEvents: InstaShowProcessEvents,
		ClearButtons: InstaShowClearButtons,
		
		LoadMetaData: InstaShowLoadMetaData,
		PrintItemMeta: InstaShowPrintItemMeta,
		SetOverlayVisible: InstaShowSetOverlayVisible,
		PlayVideo: InstaShowPlayVideo,
		
		Run: InstaShowRun,
				
		ContentCount: function() : return m.contentArray.Count() : end function
		GetOnscreen: function() : return m.contentArray[m.playbackPosition] : end function

		' events
		HandleSlideShowEvent: InstaShowHandleSlideShowEvent,
		
		Close: InstaShowClose
		
	}

    this.ss.SetMessagePort(this.port)
	this.ss.SetCertificatesFile("common:/certs/ca-bundle.crt")
	this.ss.InitClientCertificates()    
	
	this.xfer.SetPort(this.port)
	this.xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
	this.xfer.InitClientCertificates()

	globals = GetGlobals()
	this.ss.SetPeriod(5)
	
	this.SetOverlayVisible(NOT RegReadBoolean(this.overlayDisableKey))
	this.ss.SetTextOverlayIsVisible(false)
	
	return this
End Function

Sub InstaShowSetOverlayVisible(visible)
	regVal = RegReadBoolean(m.overlayDisableKey)
	if visible
		m.ss.SetTextOverlayHoldTime(3000)
	else
		m.ss.SetTextOverlayIsVisible(false)
		m.ss.SetTextOverlayHoldTime(0)
	end if
	valToWrite = NOT visible
	if valToWrite <> regVal
		LogShowStartMessage("caption disable: " + tostr(valToWrite))
		RegWriteBoolean(m.overlayDisableKey, valToWrite)
	end if
End Sub

Function InstaShowSetNext()
	m.playbackPosition = m.playbackPosition + 1
	if m.playbackPosition = m.contentArray.Count() then
		print "InstaShowSetNext rolling over to 0, from count:" + tostr(m.contentArray.Count())
		m.playbackPosition = 0
	end if
	return m.contentArray[m.playbackPosition]
End Function

Function InstaShowSetPrevious()
	m.playbackPosition =  m.playbackPosition - 1
	if m.playbackPosition < 0 then
		m.playbackPosition = m.contentArray.Count() - 1
		print "InstaShowSetNext rolling under to:" + tostr(m.playbackPosition)
	end if
	return m.contentArray[m.playbackPosition]
End Function

Sub InstaShowClose()
	m.ss.Close()
	m.xfer.AsyncCancel()
	'm.ss = invalid
	'm.xfer = invalid
	HideRadioDiag()
End Sub


Sub InstaShowClearButtons()
	m.ss.ClearButtons()
	m.buttons = invalid
End Sub

Sub InstaShowRun()

	globals = GetGlobals()
	
	InitRadio()
	
	if NOT globals.hasBrowsed
		
		tipText = "During slideshow .. " 
		tipText = tipText + Chr(10) + "DOWN will browse to details"
		
		if globals.features.video
			tipText =  tipText + " or to play video" 
		end if
		
		tipText = tipText + Chr(10) + "OK will like a photo" 
		
		if globals.features.music
			tipText = tipText + Chr(10) + "* (asterisk) brings up music control" 
		end if
		ShowDialog1Button("Tip", tipText , "Got It!")
		globals.hasBrowsed = true
		RegWrite("hasBrowsed", "true", globals.constants.sections.default)
	end if
	
	m.ss.Show()
	
	GaScreenView(m.screenName).PostAsync()
	
	for each screen in globals.screenStack
		screen.shouldClose = true
		screen.Close()
	next
	
	globals.screenStack = []
	globals.screenStack.Push(m)
	
	
	if m.parsedResponse = invalid then
		req = CreateInstaRequest(m.port)
		req.endpoint = m.endpoint
	    req.StartGetToString()
	    
	    
	    m.busyDialog = CreateObject("roOneLineDialog")
	    m.busyDialog.SetMessagePort(m.port)
	    loadingMsg = "Loading"
	    title = "<N/A>"
	    if m.title <> invalid
	    	title = m.title
	    	loadingMsg = loadingMsg + " " + m.title
	    end if
	    
	    LogShowStartMessage("Starting show '" + title + "'", req)
	    
		m.busyDialog.SetTitle(loadingMsg)
		m.busyDialog.ShowBusyAnimation()
		m.busyDialog.Show()
	    
	else 
		m.LoadMetaData(m.parsedResponse)
    end if
    
	
    'MarkRadioTimestamp()
	
	m.ProcessEvents()
		
End Sub


Sub InstaShowAddRequest(request)
	GetGlobals().radio.reqHash[Stri(request.identity)] = request
End Sub

Function InstaShowLoadMetaData(parsedResponse) 
	globals = GetGlobals()
	ret = 0
	
	
	
	if parsedResponse.meta.code = 200 then
		loadNew = false
		
		if parsedResponse.pagination <> invalid then
			if parsedResponse.pagination.next_url <> invalid
				m.nextUrl = parsedResponse.pagination.next_url
			else
				m.nextUrl = "end"
			end if
		end if
	
		if m.contentArray <> invalid then
			print "LoadMetaData:: m.contentArray.Count(): " + Stri(m.contentArray.Count()) + ", parsedResponse.data.Count(): " + Stri(parsedResponse.data.Count())
		end if
		if m.contentArray = invalid OR (m.contentArray.Count() + parsedResponse.data.Count() > m.maxSlides) then
			print "loading up new content array"
			m.contentArray = CreateObject("roArray", m.maxSlides, false)
			loadNew = true
		else 
			ret = m.contentArray.Count() - 1
		end if

		for each item in parsedResponse.data
			contentItem = {}
			contentItem.url = HackStripHttps(item.images.standard_resolution.url)
			
			textOverLayUL = ""
			if item.user <> invalid AND item.user.username <> invalid then
				textOverLayUL = item.user.username
			end if
			
			if globals.features.video 
				if item.type <> invalid AND item.type = "video"
					textOverLayUL = textOverLayUL + " " + Chr(183) + " " + item.type
				end if
			end if
			
			'if item.location <> invalid
			'	if item.location.name <> invalid
			'		textOverLayUL = textOverLayUL + " " + Chr(183) + " " + item.location.name
			'	else 
			'		if globals.localhost AND item.location.latitude <> invalid AND item.location.longitude <> invalid
			'			textOverLayUL = textOverLayUL + " " + Chr(183) + " " + tostr(item.location.latitude) + "," + tostr(item.location.longitude)
			'		end if
			'	end if
			'end if
			
			textOverLayUR = ""
			if item.likes <> invalid AND item.likes.count <> invalid then
				textOverLayUR = textOverLayUR + Stri(item.likes.count) + " likes"
			end if
			
			if item.created_time <> invalid then
				timeAgo = FormatTimeAgo(item.created_time.ToInt())
				textOverLayUR = textOverLayUR + " " + Chr(183) + " " + timeAgo + " ago"
			end if
			
			contentItem.TextOverlayUL = textOverLayUL
			contentItem.TextOverlayUR = textOverLayUR
			
			if item.caption <> invalid AND item.caption.text <> invalid
				contentItem.TextOverlayBody = item.caption.text
			end if
				
			contentItem.insta = item
			m.contentArray.Push(contentItem)
			if NOT loadNew then
				m.ss.AddContent(contentItem)
			end if
			created_time_formatted = "N/A"
			if item.created_time <> invalid then
				created_time = item.created_time.toInt()
				if m.oldestItem = invalid then
					m.oldestItem = created_time
				else
					if m.oldestItem > created_time then
						m.oldestItem = created_time
					end if
				end if
			end if
			'print Stri(m.contentArray.Count() - 1) + ": " + item.id + " :: " + created_time_formatted + " :: " + item.user.username
			print "  ";
			m.PrintItemMeta(m.contentArray.Count() - 1, item)
		next
		
		if loadNew then
			m.ss.SetContentList(m.contentArray)
			m.startNextXferIndex = 3
		else
			m.startNextXferIndex = ret + 1
		end if
		
		print "Set startNextXferIndex to " + tostr(m.startNextXferIndex)
	
	end if
	
	return ret
	
End Function

Sub InstaShowPrintItemMeta(index, item, log=false)
	dateTime = CreateObject("roDateTime")
	dateTime.fromSeconds(item.created_time.toInt())
	dateTime.toLocalTime()

	year = Stri(dateTime.getYear()).Trim()

	month = Stri(dateTime.getMonth()).Trim()
	if (Len(month) = 1) then
		month = " " + month
	end if
	
	dom = Stri(dateTime.getDayOfMonth()).Trim()
	if (Len(dom) = 1) then
		dom = " " + dom
	end if
	
	hours = Stri(dateTime.getHours()).Trim()
	if (Len(hours) = 1) then
		hours = " " + hours
	end if
	minutes = Stri(dateTime.getMinutes()).Trim()
	if (Len(minutes) = 1) then
		minutes = "0" + minutes
	end if
	seconds = Stri(dateTime.getSeconds()).Trim()
	if (Len(seconds) = 1) then
		seconds = "0" + seconds
	end if
	
	created_time_formatted = month + "/" + dom + "/" + year + " " + hours + ":" + minutes + ":" + seconds
	indexStr = Stri(index).Trim()
	total = Stri(m.contentArray.Count() - 1).Trim()
	if (Len(total) = 1) then
		total = " " + total
	end if
	print String(2 - Len(indexStr)," ") + Stri(index) + "/" + total + ": " + String(30-Len(item.id), " ") + item.id + " :: " +  created_time_formatted + " (" + item.created_time + ") :: " + item.user.username
	'print item.images.standard_resolution
	if log
		LogSlideViewMessage(String(2 - Len(indexStr)," ") + Stri(index) + "/" + total + ": " +  created_time_formatted + " :: by " + item.user.username)
	end if
End Sub

Function InstaShowProcessEvents()
	
	globals = GetGlobals()
	
	while true

		msg = WaitForEvent(0, m.port)
		
		if msg <> invalid then
			if type(msg)="roUrlEvent" then
				if msg.GetInt() = 1 then
					identity = msg.GetSourceIdentity()
					
					json = msg.GetString()
					
					'print chr(10) + "response:" + json + chr(10)
					identityKey = Stri(identity)
				
					if msg.GetResponseCode() = 200 then
						if m.nextInstaRequest <> invalid AND identity = m.nextInstaRequest.identity then
							m.nextParsedResponse = ParseJson(json)
							m.nextInstaRequest = invalid
							print "response (" + Stri(identity) + ") contains " + Stri(m.nextParsedResponse.data.Count()) + " items"

						else 
							parsedResponse = ParseJson(json)
							print "media response returned " + Stri(parsedResponse.data.Count()) + " items"
							
							if m.busyDialog <> invalid then
								m.busyDialog.Close()
							end if
							m.LoadMetaData(parsedResponse)
							
						end if
					else
						print "ERROR: unexpected return code: " + Stri(msg.GetResponseCode()) + ", reason:" + msg.GetFailureReason()
						if json <> invalid
							print json
						end if
					end if
				end if
					
			else if type(msg)="roMessageDialogEvent" then
				HandleMessageDialogEvent(msg)
			else if type(msg)="roSlideShowEvent" then
				if m.HandleSlideShowEvent(msg) > 0 then
					print "Returning from slide show"
					return 0
				end if
			else
				print "InstaShowProcessEvents::WARNING received event type:" + type(msg)
				if msg = invalid then
					print "Bailing!"
					return 0
				end if
			end if
		end if
		
		
	end while
		
	return 0
	
End Function


Function InstaShowHandleSlideShowEvent(msg)
	'print "roSlideShowEvent. Type ";msg.GetType();", index ";msg.GetIndex();", Data ";msg.GetData();", msg ";msg.GetMessage()
	globals = GetGlobals()
	
	if msg.isScreenClosed() then
		print "roSlideShowEvent::ScreenClosed"
		if globals.features.music
			print "NOT PAUSING BC CLOSED!!!"
			'PauseRadio()
		end if
		m.Close()
		return 1
	else if msg.IsPaused()
	
		GaEvent(type(msg), GetMsgAction(msg)).SetNonInteractive().PostAsync()
		
		m.overlayVisible = true
		
		if NOT m.remoteOkPressed
			'if globals.features.music
			'	PauseRadio()
			'end if
			m.paused = true
		end if
		
		likeToggleCaption = "Like"
		if m.contentItem.insta.user_has_liked <> invalid AND m.contentItem.insta.user_has_liked
			likeToggleCaption = "Unlike"
		end if

		if NOT m.buttonsShowing AND m.remoteOkPressed
			captionToggleCaption = "Turn captions off"
			if RegReadBoolean(m.overlayDisableKey)
				captionToggleCaption = "Turn captions on"
			end if
			
			if globals.features.video AND m.contentItem.insta.type = "video"
				m.ss.AddButton(m.btnPlayVideo, "Play video")
			end if
			
			m.ss.AddButton(m.btnToggleLike, likeToggleCaption)
			m.ss.AddButton(m.btnToggleCaptions, captionToggleCaption)
			'm.ss.AddButton(m.btnComment, "Comment")
			m.ss.AddButton(m.btnClose, "Close")
			
			m.buttonsShowing = true
		end if
		m.remoteOkPressed = false

	else if msg.IsResumed() then
		
		GaEvent(type(msg), GetMsgAction(msg)).SetNonInteractive().PostAsync()
	
		if m.buttonsShowing
			m.ss.ClearButtons()
			m.buttonsShowing = false
		end if

		m.overlayVisible = false
		m.paused = false
		m.ss.SetNext((m.playbackPosition + 1) MOD m.contentArray.Count(), true)
		m.remoteOkPressed = false
		
	else if msg.isRemoteKeyPressed()
		print "roSlideShowEvent::RemoteKeyPressed, index:" + tostr(msg.GetIndex()) + ", paused:" + tostr(m.paused)
		
		GaEvent(type(msg), GetKeyPressName(msg)).PostAsync()
		
		if msg.GetIndex()=10 then
			if globals.features.music
				if not m.paused then
					m.ss.Pause()
				end if
				
				globals.radio.asp.Run()
				
				if m.playbackPosition <> invalid then
					m.ss.SetNext(m.playbackPosition, true)
				end if
				
				if not m.paused then
					m.ss.Resume()
				end if
			end if
		else if msg.GetIndex()=3 
			if not m.paused then
				m.ss.Pause()
			end if
			
			mediaSpringBoard = CreateMediaSpringBoardScreen(m.contentItem.insta)
			mediaSpringBoard.SetInstaShow(m)
			mediaSpringBoard.Run()
			
			if m.playbackPosition <> invalid then
				m.ss.SetNext(m.playbackPosition, true)
			end if
			
			if not m.paused then
				m.ss.Resume()
			end if
		else if msg.GetIndex() = 6
			m.remoteOkPressed = true
		end if

	else if msg.isButtonPressed() then
		
		print "roSlideShowEvent::ButtonPressed index:" + tostr(msg.GetIndex())
				
		autoResume = true
		if msg.GetIndex() = m.btnToggleLike
			if GetCurrentUser() <> invalid
				likeRequest = CreateInstaRequest()
				likeRequest.endpoint = "/media/" + m.contentItem.insta.id + "/likes"
				lkmsg = invalid
				if m.contentItem.insta.user_has_liked then
					lkmsg = likeRequest.DeleteWithStatus("Removing like..")
					if lkmsg <> invalid
						GaSocial("unlike", m.contentItem.insta.id).PostAsync()
					end if
					LogShowStartMessage("removing like from id:" + m.contentItem.insta.id)
					m.contentItem.insta.user_has_liked = false
				else
					lkmsg = likeRequest.PostWithStatus("Liking...")
					if lkmsg <> invalid
						GaSocial("like", m.contentItem.insta.id).PostAsync()
					end if
					LogShowStartMessage("liking id:" + m.contentItem.insta.id)
					
					m.contentItem.insta.user_has_liked = true
				end if
			else
				ShowDialog1Button("Not linked", "You must link an account to use this feature",  "Close")
			end if
		else if msg.GetIndex() = m.btnToggleCaptions
			regVal = RegReadBoolean(m.overlayDisableKey)
			m.SetOverlayVisible(regVal)
			GaEvent(type(msg), GetMsgAction(msg), "SetOverlayVisible(" + tostr(regVal) + ")", invalid).PostAsync()

		else if msg.GetIndex() = m.btnComment
			if GetCurrentUser() <> invalid
				cannedComment = "Looks great on my TV using @getrokagram"
				ret = ShowDialog2Buttons("Add Comment", Chr(34) + cannedComment + Chr(34), "Add Comment", "Close")
				if ret = 0
					commentRequest = CreateInstaRequest()
					commentRequest.endpoint = "/media/" + m.contentItem.insta.id + "/comments"
					commentRequest.AddBodyParam("text", cannedComment)
					msg = commentRequest.PostWithStatus("Commenting...")
					LogShowStartMessage("commenting on id:" + m.contentItem.insta.id)
				
				end if
			else
				ShowDialog1Button("Not linked", "You must link an account to use this feature",  "Close")
			end if
		else if msg.GetIndex() = m.btnPlayVideo
			autoResume = false
			m.PlayVideo(m.contentItem)
		else if msg.GetIndex() = m.btnClose
		
			print "btnClose"
		end if
		
		if autoResume
			m.ss.ClearButtons()
			m.buttonsShowing = false
			
			if NOT m.paused
				print "calling ss.Resume()"
				m.ss.Resume()
			else
				print "I guess I'm m.paused"
				'm.ss.Resume()
			end if
		
		end if

		if RegReadBoolean(m.overlayDisableKey)
			m.ss.SetTextOverlayIsVisible(false)
			m.ss.SetTextOverlayHoldTime(0)
		end if
		
		
	else if msg.isPlaybackPosition()
	
		GaEvent(type(msg), GetMsgAction(msg), invalid, msg.GetIndex()).SetNonInteractive().PostAsync()
		
		prev = m.playbackPosition
		m.playbackPosition = msg.GetIndex()
		m.contentItem = m.contentArray[m.playbackPosition]
		if NOT (m.paused AND prev = m.playbackPosition) then
			print "=>";
			m.PrintItemMeta(m.playbackPosition, m.contentItem.insta, false)
		end if
		
		if (m.playbackPosition = m.contentArray.Count() - 1) AND (m.nextParsedResponse <> invalid) then
			nextIndex = m.LoadMetaData(m.nextParsedResponse)
			m.nextParsedResponse = invalid
		end if
		
		if m.busyDialog <> invalid then
			m.busyDialog.Close()
			m.busyDialog = invalid
		end if
		
	else if msg.isRequestSucceeded()
		
		if msg.GetIndex() > m.startNextXferIndex
			if (m.nextEndpoint <> invalid OR m.nextUrl <> invalid) AND m.nextParsedResponse = invalid
				if m.nextInstaRequest = invalid then
			    	m.nextInstaRequest = CreateInstaRequest(m.port)
			    	if m.nextUrl = invalid 
				    	m.nextInstaRequest.endpoint = m.nextEndpoint
				    	m.nextInstaRequest.qparams = m.nextEndpointParams
				    	if m.oldestItem <> invalid then
				    		if m.nextInstaRequest.endpoint = "/media/search"
				    			m.nextInstaRequest.AddQueryParam("max_timestamp", m.oldestItem)
				    		end if
				    		m.oldestItem = invalid
				    	else
				    		m.nextInstaRequest = invalid
				    	end if
			    	else
			    		if m.nextUrl = "end"
			    			m.nextInstaRequest = invalid
			    		else 
				    		m.nextInstaRequest.url = m.nextUrl
			    		end if
			    	end if
			    	
			    	if m.nextInstaRequest <> invalid
			    		print "Starting gts for nextInstaRequest at req succeed: " + tostr(msg.GetIndex())
			    		m.nextInstaRequest.StartGetToString()
			    	end if
			    else
			    	print "roSlideShowEvent::RequestSucceeded::" + Stri(msg.GetIndex()) + " instarequest already running"
		    	end if
			end if
		end if
		
	else if msg.isRequestFailed()
		print "roSlideShowEvent::RequestFailed::" + Stri(msg.GetIndex()) 
		GaException("RequestFailed").PostAsync()
	else if msg.isRequestInterrupted()
		print "roSlideShowEvent::RequestInterrupted::" + Stri(msg.GetIndex())
		GaException("RequestInterrupted").PostAsync()
	end if
	return 0						    	
End Function							   

Function FormatTimeAgo(pastEvent As Integer) As String
	ret = invalid
	
	SEC = 1
	MIN = SEC * 60
	HOUR = MIN * 60
	DAY = HOUR * 24
	WEEK = DAY * 7
	YEAR = WEEK * 52

	if (pastEvent <> invalid) then
		now = CreateObject("roDateTime").AsSeconds()

		diffMs = now - pastEvent

		'years = Int(diffMs / YEAR)
		weeks = Int(diffMs / WEEK)
		days = Int(diffMs / DAY)
		hours = Int(diffMs / HOUR)
		minutes = Int(diffMs / MIN)
		seconds = Int(diffMs / SEC)

		'if (years > 0) then
		'	ret = Stri(years) + "y"
		if (weeks > 0) then
			ret = Stri(weeks) + "w"
		else if (days > 0) then
			ret = Stri(days) + "d"
		else if (hours > 0) then
			ret = Stri(hours) + "h"
		else if (minutes > 0) then
			ret = Stri(minutes) + "m"
		else if (seconds > 0) then
			ret = Stri(seconds) + "s"
		end if
	end if
	if ret = invalid
		ret = "inavlid"
	end if
	return ret
				    	
End Function				    	
				    	
Sub InstaShowPlayVideo(meta)

'	PauseRadio()
	PlayInstagramVideo(meta.insta)
'	PlayRadio()
	    	
End Sub