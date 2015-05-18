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
Sub LogStartupMessage(message As String)
	LogMessage(message, "startup")
End Sub

' do this one synchronously
Sub LogExitingMessage(message As String)

	xml = CreateLogMessageXml(message, "shutdown")
	
	eventPostRequest = CreateRokaRequest(GetGlobalPort())
	url = GetServer() + "/api/logs"
	eventPostRequest.xfer.SetUrl(url)

	eventPostRequest.xfer.PostFromString(xml)
	
End Sub

Sub LogShowStartMessage(message As String,  instareq=invalid)
	LogMessage(message, "slideshow", instareq)
End Sub

Sub LogRegistryMessage(message As String,  instareq=invalid)
	LogMessage(message, "registry", instareq)
End Sub


Sub LogSlideViewMessage(message As String,  instareq=invalid)
	LogMessage(message, "slideview", instareq)
End Sub

Sub LogVideoMessage(message As String,  instareq=invalid)
	LogMessage(message, "video", instareq)
End Sub


Sub LogSpringBoardMessage(message As String,  instareq=invalid)
	LogMessage(message, "springboard", instareq)
End Sub

Sub LogAboutMessage(message As String,  instareq=invalid)
	LogMessage(message, "about", instareq)
End Sub

Sub LogRegScreenMessage(message As String)
	LogMessage(message, "regscreen")
End Sub

Sub LogRadioMessage(message As String,  instareq=invalid)
	LogMessage(message, "radio", instareq)
End Sub

Sub LogFeedfmStartMessage(message As String,  instareq=invalid)
	LogMessage(message, "ffmstart", instareq)
End Sub


Sub LogScreenSaverMessage(message As String,  instareq=invalid)
	LogMessage(message, "screensaver", instareq)
End Sub

Sub LogStoreMessage(message As String,  instareq=invalid)
	LogMessage(message, "store", instareq)
End Sub

Sub LogDebugMessage(message As String,  instareq=invalid)
	LogMessage(message, "debug", instareq)
End Sub

Sub LogErrorMessage(message As String,  instareq=invalid)
	LogMessage(message, "error", instareq)
End Sub

Sub LogSearchMessage(message As String,  instareq=invalid)
	LogMessage(message, "search", instareq)
End Sub

Function CreateLogMessageXml(message As String, logtype=invaid, instareq=invalid)

	globals = GetGlobals()
	
	root = CreateObject("roXMLElement")
	root.SetName("log")
	dt = CreateObject("roDateTime")
	dt.mark()
	timeStr = tostr(dt.asSeconds())
	root.AddElementWithBody("time", timeStr)
	if logtype = invalid
		logtype = "default"
	end if
	root.AddElementWithBody("type", logtype)
	currentUser = GetCurrentUser()
	if currentUser <> invalid then
		root.AddElementWithBody("userid", currentUser.id)
		root.AddElementWithBody("username", currentUser.username)
	end if
	if message = invalid
		message = ""
	end if
	root.AddElementWithBody("message", message)
	if instareq <> invalid then
		if type(instareq) = "String"
			root.AddElementWithBody("instareq", instareq)
		else
			if instareq.url <> invalid then
				root.AddElementWithBody("instareq", instareq.url)
			end if
		end if
	end if
	
	for each clientStats in globals.stats.clients
	
		stats = globals.stats.clients[clientStats]
	
		clientElement = root.AddElement("client")
		clientElement.AddAttribute("client_id", clientStats)
		
		if stats.rateLimit <> invalid 
			clientElement.AddElementWithBody("rateLimit", stats.rateLimit)
		end if
		
		if stats.rateLimitRemaining <> invalid 
			clientElement.AddElementWithBody("rateLimitRemaining", stats.rateLimitRemaining)
		end if
		
	next
	
	return root.GenXml(false)
	
End Function

Sub LogMessage(message As String, logtype=invaid, instareq=invalid)
		
	globals = GetGlobals()
	
	xml = CreateLogMessageXml(message, logtype, instareq)
	
	if globals.logging.reqCount < 5 then
		eventPostRequest = CreateRokaRequest(GetGlobalPort())
		url = GetServer() + "/api/logs"
		eventPostRequest.xfer.SetUrl(url)
		identity = Stri(eventPostRequest.identity)

		eventPostRequest.xfer.AsyncPostFromString(xml)
		
		globals.logging.reqHash[identity] = eventPostRequest
		globals.logging.reqCount = globals.logging.reqCount + 1
		
	else 
		print "Error, too many logs, skipping this one"
	end if
	
	
End Sub