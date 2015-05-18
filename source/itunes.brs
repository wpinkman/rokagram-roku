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

Function CreateItunesRequest(port=GetGlobalPort()) As Object
	globals = GetGlobals()
	this = {
		apiBase: "https://itunes.apple.com/search",
		
		type: "itunes",
		xfer: CreateObject("roUrlTransfer"),
		
		params: invalid,
		
		AddParam: ItunesRequestAddParam,
		BuildAlbumRequestFromAlbumTitle: ItunesRequestBuildAlbumRequestFromAlbumTitle,
		BuildAlbumRequestFromTrackTitle: ItunesRequestBuildAlbumRequestFromTrackTitle,
				
		StartGetToString: ItunesRequestStartGetToString,
		GetToString: ItunesRequestGetToString,
		
		Close: function() : m.xfer.AsyncCancel() : m.xfer = invalid : return m.xfer : end function
	}

	if port <> invalid then
		this.xfer.SetPort(port)
	end if
	
	' allow for HTTPS
	this.xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
	this.xfer.EnablePeerVerification(false)
	this.xfer.InitClientCertificates()
	
	this.identity = this.xfer.GetIdentity()
	
	return this
End Function

Sub ItunesRequestClearParams()
	if m.params <> invalid then
		m.params = invalid
	end if
End Sub

Sub ItunesRequestAddParam(name,value)
	if m.params = invalid then
		m.params = []
	end if
	param = {}
	param.name = name
	param.value = value
	m.params.Push(param)
End Sub

Sub ItunesRequestBuildAlbumRequestFromAlbumTitle(albumName)

	m.AddParam("term", albumName)
	m.AddParam("media", "music")
	m.AddParam("entity", "album")
	m.AddParam("attribute", "albumTerm")
	'm.AddParam("limit", "1")

End Sub

Sub ItunesRequestBuildAlbumRequestFromTrackTitle(trackTitle)

	m.AddParam("term", trackTitle)
	m.AddParam("media", "music")
	m.AddParam("entity", "album")
	m.AddParam("attribute", "songTerm")
	'm.AddParam("limit", "1")

End Sub

Sub ItunesRequestStartGetToString()

	url = m.apiBase 
	query = ""
	if m.params <> invalid then
		for each param in m.params
			if type(param.value) = "roInteger" then
				val = Stri(param.value).Trim()
			else
				val = param.value
			end if
			encodedNvp =  m.xfer.UrlEncode(param.name) + "=" + m.xfer.UrlEncode(val)
			if query = "" then
				query = encodedNvp
			else
				query = query + "&" + encodedNvp
			end if
		next
	end if
	
	url = url + "?" + query
	
    print "(" + tostr(m.identity) + ") : iTunes request: " + url 
    m.url = url
    m.xfer.SetUrl(m.url)
    m.xfer.AsyncGetToString()
	
End Sub

Function ItunesRequestGetToString()
	
	port = CreateObject("roMessagePort")
	m.xfer.SetPort(port)
	
	m.StartGetToString()
	return WaitForHttp(50, port)
	
End Function



	
	