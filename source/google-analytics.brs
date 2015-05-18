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

Function GaScreenView(screename)

	ga = CreateGoogleAnalytics()
	if GetGlobals().ga.screens 
		ga.AddParam("t", "screenview")
	end if
	ga.AddParam("cd", screename)
		
	return ga
	
End Function

Function GaEvent(category, action, label=invalid, value=invalid)

	ga = CreateGoogleAnalytics()
	if GetGlobals().ga.events
		ga.Event(category, action, label, value)
	end if
	
	return ga
	
End Function

Function GaTiming(category, name, milliseconds)

	ga = CreateGoogleAnalytics()
	if GetGlobals().ga.timing
		ga.Timing(category, name, milliseconds)
	end if
	return ga

End Function

Function GaException(description = invalid, isfatal = invalid)
	ga = CreateGoogleAnalytics()
	if GetGlobals().ga.exceptions
		ga.AddParam("t", "exception")
	end if
	ga.SetNonInteractive()
	
	if description <> invalid
		ga.AddParam("exd", description)
	end if
	
	exf = "0"
	if isfatal <> invalid AND isbool(isfatal) AND isfatal
		exf = "1"
	end if
	ga.AddParam("exf", exf)

	return ga

End Function

Function GaSocial(action, target)

	ga = CreateGoogleAnalytics()
	if GetGlobals().ga.social
		ga.AddParam("t", "social")
	end if
	ga.AddParam("sn", "instagram")
	ga.AddParam("sa", action)
	ga.AddParam("st", target)
		
	return ga

End Function

Function CreateGoogleAnalytics() As Object
	this = {
		
		' non-SSL base: http://www.google-analytics.com/collect
		'url: "https://ssl.google-analytics.com/collect",
		url: "http://www.google-analytics.com/collect",
		bparams: invalid,
		hasTypeParam: false,
		
		type: "googleanalytics",
		
		port: CreateObject("roMessagePort"),
		xfer: CreateObject("roUrlTransfer"),
		
		identity: invalid,
		
		AddParam: GoogleAnalyticsRequestAddBodyParam,
		BuildUrl: GoogleAnalyticsRequestBuildUrl,
		
		Event: GoogleAnalyticsEvent,
		Timing: GoogleAnalyticsTiming,
		
		' Session control
		SetSessionStart: function() : m.AddParam("sc", "start") : return m : end function
		SetSessionEnd: function() : m.AddParam("sc", "end") : return m : end function
		
		SetNonInteractive: function() : m.AddParam("ni", "1") : return m : end function
		
		PostAsync: GoogleAnalyticsPostAsync,
		Post: GoogleAnalyticsPost,
				
		Close: function() : m.xfer.AsyncCancel() : m.xfer = invalid : return m.xfer : end function
	}

	' allow for HTTPS
	'this.xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
	'this.xfer.InitClientCertificates()

	this.xfer.SetPort(GetGlobalPort())
	
	user = GetCurrentUser()
	globals = GetGlobals()
	
	this.identity = this.xfer.GetIdentity()
	
	' see https://developers.google.com/analytics/devguides/collection/protocol/v1/parameters
	
	if globals.ga <> invalid
	
		this.AddParam("v", 1)
		
		if globals.saver
			if globals.ga.sstid <> invalid
				this.AddParam("tid", globals.ga.sstid)
			end if
		else
			if globals.ga.tid <> invalid
				this.AddParam("tid", globals.ga.tid)
			end if
		end if
		
		this.AddParam("ds", "roku")
		this.AddParam("sr", globals.ga.sr)
		
		if globals.ga.cid <> invalid
			this.AddParam("cid", globals.ga.cid)
		end if
		
		if user <> invalid
			this.AddParam("uid", user.username)
		end if
		
		
		this.AddParam("an", "rokagram")
		this.AddParam("av", globals.cversion)
		
		
	end if
	
	return this
	
End Function

Sub GoogleAnalyticsEvent(category, action, label=invalid, value=invalid)
		
	m.AddParam("t", "event")
	
	' event category
	m.AddParam("ec", category)
	m.AddParam("ea", action)

	if label <> invalid
		m.AddParam("el", label)
	end if
		
	if value <> invalid
		m.AddParam("ev", value)
	end if
		
End Sub

Sub GoogleAnalyticsTiming(category, name, milliseconds)
	m.AddParam("t", "timing")
	m.AddParam("utc", category)
	m.AddParam("utv", name)
	m.AddParam("utt", milliseconds)

End Sub


Sub GoogleAnalyticsRequestAddQueryParam(name,value)
	print "add query " + name + " = " + tostr(value)
	if m.qparams = invalid then
		m.qparams = []
	end if
	param = {}
	param.name = name
	param.value = value
	m.qparams.Push(param)
End Sub

Sub GoogleAnalyticsRequestAddBodyParam(name,value)
	if m.bparams = invalid then
		m.bparams = []
	end if
	param = {}
	param.name = name
	param.value = value
	m.bparams.Push(param)
End Sub

Sub GoogleAnalyticsRequestBuildUrl()
	
	m.hasTypeParam = false
	if m.bparams <> invalid then
		for each param in m.bparams
			val = tostr(param.value)
			if param.name <> invalid AND param.name = "t"
				m.hasTypeParam = true
			end if
			if m.body = invalid then
				m.body =  m.xfer.UrlEncode(param.name) + "=" + m.xfer.UrlEncode(val)
			else
				m.body = m.body + "&" + m.xfer.UrlEncode(param.name) + "=" + m.xfer.UrlEncode(val)
			end if
		next
	end if
		
	'print "---------------------------"
    'print "curl --data " + Chr(34) + m.body + Chr(34) + " " + m.url
    'print "---------------------------"
    
    m.xfer.SetUrl(m.url)
    
End Sub



Sub GoogleAnalyticsPostAsync()

	globals = GetGlobals()
	 
	if globals.ga.reqCount < 5 then

		identityKey = Stri(m.identity)
		
		m.BuildUrl()
		if m.hasTypeParam
			m.xfer.AsyncPostFromString(m.body)
			globals.ga.reqHash[identityKey] = m
			globals.ga.reqCount = globals.ga.reqCount + 1
		else
			print ">>>>>>> skipping do to lack of type"
		end if
		
	else 
		print "ERROR, too many events, skipping this one"
	end if
	

End Sub

Sub GoogleAnalyticsPost()
	
	m.BuildUrl()
	if m.hasTypeParam
		m.xfer.PostFromString(m.body)
	end if
	
End Sub

