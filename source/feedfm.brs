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

Function CreateFeedFmRequest(port=GetGlobalPort()) As Object
	globals = GetGlobals()
	this = {
		apiBase: "https://feed.fm/api/v2/",
		endpoint: invalid,
		
		type: "feedfm",
		reqType: "",
		
		placement: globals.feedfm.placement,
		station: globals.feedfm.station,
		xfer: CreateObject("roUrlTransfer"),
		
		params: invalid,
		
		AddParam: FeedFmRequestAddParam,
		ClearParams: FeedFmRequestClearParams,
				
		StartGetToString: FeedFmRequestStartGetToString,
		GetToString: FeedFmRequestGetToString,
		AsyncPostFromString: FeedFmAsyncPostFromString,
		BuildXfer: FeedFmRequestBuildXfer,
		
		AsyncPlay: FeedFmAsyncPlay,
		AsyncPlayStart: FeedFmAsyncPlayStart,
		AsyncPlayComplete: FeedFmAsyncPlayComplete,
		AsyncPlaySkip: FeedFmAsyncPlaySkip,
		AsyncPlayInvalidate: FeedFmAsyncPlayInvalidate,
		
		AsyncGetPlacement: FeedFmAsyncGetPlacement,
		
		Close: function() : m.xfer.AsyncCancel() : m.xfer = invalid : return m.xfer : end function
	}

	if port <> invalid then
		this.xfer.SetPort(port)
	end if
	
	' copied and pasted out of API explorer http://developer.feed.fm/documentation/explorer
	this.xfer.AddHeader("Authorization", "Basic " + globals.feedfm.basicAuth)
	
	' allow for HTTPS
	this.xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
	this.xfer.EnablePeerVerification(false)
	this.xfer.InitClientCertificates()
	
	this.identity = this.xfer.GetIdentity()
	
	return this
End Function

Sub FeedFmRequestClearParams()
	if m.params <> invalid then
		m.params = invalid
	end if
End Sub

Sub FeedFmRequestAddParam(name,value)
	if m.params = invalid then
		m.params = []
	end if
	param = {}
	param.name = name
	param.value = value
	m.params.Push(param)
End Sub

Sub FeedFmRequestStartGetToString()

	url = m.apiBase + m.endpoint

	payload = ""
	
	if m.params <> invalid then
		for each param in m.params
			if type(param.value) = "roInteger" then
				val = Stri(param.value).Trim()
			else
				val = param.value
			end if
			encodedNvp =  m.xfer.UrlEncode(param.name) + "=" + m.xfer.UrlEncode(val)
			if payload = "" then
				payload = encodedNvp
			else
				payload = payload + "&" + encodedNvp
			end if
		next
	end if
	
    print "request: " + url 
    m.url = url
    m.xfer.SetUrl(m.url)
    m.xfer.AsyncGetToString()
	
End Sub

Sub FeedFmRequestBuildXfer()
	
	url = m.apiBase + m.endpoint + CreateQueryString(m.params)
	m.xfer.SetUrl(url)
	print "FeedFmRequestBuildXfer: " + url
	
End Sub


Sub FeedFmAsyncPostFromString(body)
	m.url = m.apiBase + m.endpoint
    m.xfer.SetUrl(m.url)
    print "POST(" + tostr(m.identity) + ") " + m.url
    if body <> "" then
    	print "   " + body
    end if
    m.xfer.AsyncPostFromString(body)
End Sub

Sub FeedFmAsyncPlay()
	m.reqType = "play"
	m.endpoint = "play"
	
	print "FeedFmAsyncPlay"
	
	client_id = GetFeedFmClientId()
	if client_id <> invalid AND m.placement <> invalid AND m.station <> invalid then
		body = "client_id=" + client_id + "&placement_id=" + m.placement + "&station_id=" + m.station '+ "&formats=mp3"
		m.AsyncPostFromString(body)
	else
		print "ERROR starting play"
	end if
End Sub

Function FeedFmAsyncPlayStart(id)
	m.reqType = "playstart"
	m.endpoint = "play/" + id + "/start"
	m.AsyncPostFromString("")
End Function	

Function FeedFmAsyncPlayComplete(id)
	m.reqType = "playcomplete"
	m.endpoint = "play/" + id + "/complete"
	m.AsyncPostFromString("")
End Function	

Function FeedFmAsyncPlayInvalidate(id)
	m.reqType = "playinvalidate"
	m.endpoint = "play/" + id + "/invalidate"
	m.AsyncPostFromString("")
End Function

Function FeedFmAsyncPlaySkip(id)
	m.reqType = "playskip"
	m.endpoint = "play/" + id + "/skip"
	m.AsyncPostFromString("")
End Function

Sub FeedFmAsyncGetPlacement()
    m.reqType = "placement"
    m.endpoint = "placement"
    m.StartGetToString()
End Sub

Function FeedFmRequestGetToString()
	
	port = CreateObject("roMessagePort")
	m.xfer.SetPort(port)
	
	m.StartGetToString()
	return WaitForHttp(50, port)
	
End Function

Sub HandleFeedFmClientResponse(msg)
	json = msg.GetString()    	
	print chr(10) + "Feed.fm response:" + json + chr(10)
	
	if msg.GetResponseCode() = 200 then
		feedFmResp = ParseJson(json)
		if feedFmResp.success then
			SetFeedFmClientId(feedFmResp.client_id)
		end if
	end if
	
	'InitRadio()
End Sub


	
	