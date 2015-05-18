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

Function CreateInstaRequest(port=invalid) As Object
	this = {
		
		url: invalid,
		
		apiBase: "https://api.instagram.com/v1",
		endpoint: invalid,
		client_id: GetClientId(),
		access_token: invalid,
		qparams: invalid,
		bparams: invalid,
		body: invalid,
		
		type: "instagram",
		
		xfer: CreateObject("roUrlTransfer"),
		
		identity: invalid,
		
		AddBodyParam: InstaRequestAddBodyParam,
		AddQueryParam: InstaRequestAddQueryParam,
		
		ClearParams: InstaRequestClearParams,
		BuildUrl: InstaRequestBuildUrl,
		
		StartGetToString: InstaRequestStartGetToString,
		GetToString: InstaRequestGetToString,
		
		PostFromString: InstaRequestPostFromString,
		DeleteFromString: InstaRequestDeleteFromString,
		
		PostWithStatus: InstaRequestPostWithStatus,
		DeleteWithStatus: InstaRequestDeleteWithStatus,
		
		ParseResponse: InstaRequestParseResponse,
		
		Close: function() : m.xfer.AsyncCancel() : m.xfer = invalid : return m.xfer : end function
	}

	' allow for HTTPS
	this.xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
	this.xfer.InitClientCertificates()
	this.xfer.SetPort(port)
	this.xfer.EnableEncodings(true)
	
	user = GetCurrentUser()
	if user <> invalid
		this.access_token = user.access_token
	end if
	
	this.identity = this.xfer.GetIdentity()
	
	return this
End Function

' Since many old browsers don't support PUT or DELETE, we've made it 
'easy to fake PUTs and DELETEs. All you have to do is do a POST with 
'_method=PUT or _method=DELETE as a parameter and we will treat it as 
'if you used PUT or DELETE respectively.

Sub InstaRequestClearParams()
	if m.qparams <> invalid then
		m.qparams = invalid
	end if
End Sub


Sub InstaRequestAddQueryParam(name,value)
	if m.qparams = invalid then
		m.qparams = {}
	end if
	m.qparams[name] = value
End Sub

Sub InstaRequestAddBodyParam(name,value)
	print "add body " + name + " = " + tostr(value)
	if m.bparams = invalid then
		m.bparams = []
	end if
	param = {}
	param.name = name
	param.value = value
	m.bparams.Push(param)
End Sub

Sub InstaRequestBuildUrl()
	debug = m.url
	if m.url = invalid then
		debug = m.endpoint
		m.url = m.apiBase + m.endpoint
		if (m.access_token <> invalid) then
			if m.bparams = invalid 
				m.url = m.url + "?access_token=" + m.xfer.UrlEncode(m.access_token)
				debug = debug  + "?access_token=<token>"
			else
				m.AddBodyParam("access_token", m.access_token)
			end if
		else 
			m.url = m.url + "?client_id=" + m.xfer.UrlEncode(m.client_id)
			debug = debug  + "?client_id=<cid>"
		end if
		if m.qparams <> invalid then
			m.qparams.Reset()
			while m.qparams.IsNext()
				key = m.qparams.Next()
				val = tostr(m.qparams[key])
			
				encoded = "&" +  m.xfer.UrlEncode(key) + "=" + m.xfer.UrlEncode(val)
				m.url = m.url + encoded
				debug = debug + encoded
				
			end while
		
			'for each param in m.qparams
			'	val = tostr(param.value)
			'	encoded = "&" +  m.xfer.UrlEncode(param.name) + "=" + m.xfer.UrlEncode(val)
			'	m.url = m.url + encoded
			'	debug = debug + encoded
			'next
		end if
		if m.bparams <> invalid then

			for each param in m.bparams
				val = tostr(param.value)
				if m.body = invalid then
					m.body =  m.xfer.UrlEncode(param.name) + "=" + m.xfer.UrlEncode(val)
				else
					m.body = m.body + "&" + m.xfer.UrlEncode(param.name) + "=" + m.xfer.UrlEncode(val)
				end if
			next
		end if
		
	end if
    print "request(" +Stri(m.identity)+ "): " + m.url 
    m.debug = debug
    m.xfer.SetUrl(m.url)
End Sub

Sub InstaRequestStartGetToString()
	m.BuildUrl()	
	m.xfer.AsyncGetToString()
End Sub

Function InstaRequestGetToString() As String
	m.BuildUrl()	
	return m.xfer.GetToString()
End Function

Function InstaRequestPostFromString(request="") 
	m.BuildUrl()	
	return m.xfer.PostFromString(request)
End Function


Function InstaRequestDeleteFromString(request="") 
	m.xfer.SetRequest("DELETE")
	m.BuildUrl()	
	return m.xfer.PostFromString(request)
End Function

Function InstaRequestDeleteWithStatus(title="Please wait ..")
	m.xfer.SetRequest("DELETE")
	return m.PostWithStatus(title)
End Function

Function InstaRequestPostWithStatus(title="Please wait ..")
	ret = invalid
	m.BuildUrl()
	port = CreateObject("roMessagePort")
	busyDialog = CreateObject("roOneLineDialog")
	m.xfer.SetPort(port)
	busyDialog.SetMessagePort(port)
	 
	busyDialog.SetTitle(title)
	busyDialog.ShowBusyAnimation()
	busyDialog.Show()
	body = ""
	if m.body <> invalid then
		body = m.body
		print "body:" + body
	end if

	m.xfer.AsyncPostFromString(body)
	
	while true
		msg = WaitForEvent(0, port)
		
		if msg <> invalid then
			if type(msg)="roUrlEvent" then
				identity  = msg.GetSourceIdentity()
				json = msg.GetString()
				print "PWS(" + tostr(identity) + "):" + "::response: code=" + Stri(msg.GetResponseCode())
				if json <> invalid
					print chr(10) + json + chr(10)
				else
					print "<empty body>"
				end if

				if msg.GetSourceIdentity() = m.identity
					busyDialog.Close()
					ret = msg
					exit while
				end if
			else if type(msg) = "roOneLineDialogEvent"
				if msg.isScreenClosed() then
					exit while
				end if
			end if
		end if
	end while
		
	return ret
	
End Function

Function InstaRequestParseResponse(json)
		
	ret = invalid
	if json <> invalid
		parsedResponse = ParseJson(json)
		if parsedResponse <> invalid
			if parsedResponse.meta.code = 200
				return parsedResponse
			else
				return "Unexpected result"
			end if
		else
			return "Unexpected result"
		end if
	else
		return "Unexpected result"
	end if
	
	return ret
		
End Function		