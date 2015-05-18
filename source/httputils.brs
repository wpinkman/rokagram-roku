Function WaitForHttp(timeout, port)
	
	ret = invalid
	
	msg = wait(timeout*1000, port)
	
	if type(msg)="roUrlEvent" then
		gi = msg.GetInt()
		if gi = 1 then
			ret = msg.GetString()
			print  "responseCode: " + Stri(msg.GetResponseCode()) + ", reason:" + msg.GetFailureReason()
		else
			print "ERROR gi:" + Stri(gi)
		end if
	end if

	return ret
	
End Function

Function HackStripHttps(url as String) As String
	
	ret = url

	globals = GetGlobals()
	
	if globals.sslPatchDomain <> invalid AND Len(globals.sslPatchDomain) > 0
		index = Instr(1, url, globals.sslPatchDomain)
		if (index > 0) 
			ret = "http://" + Mid(url, index, Len(url) - index + 1)
		end if
	end if
	
	return ret
End Function

Function GetImage(url)
	xfer = CreateObject("roUrlTransfer")
	port = CreateObject("roMessagePort")
	
	xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
	xfer.InitClientCertificates()
	xfer.SetPort(port)
	
	print "Getting to File: " + url
	xfer.SetUrl(url)
	file = "tmp://bar.img"
	xfer.AsyncGetToFile(file)
	WaitForHttp(1000, port)
	fs = CreateObject("roFileSystem")
	sr = fs.stat(file)

	return file
End Function

Function CreateQueryString(nameValuePairs)

	ret = ""
	if nameValuePairs <> invalid
		xfer = CreateObject("roUrlTransfer")
		
		if nameValuePairs <> invalid then
			for each nvp in nameValuePairs
				encodedNvp =  xfer.UrlEncode(nvp.name) + "=" + xfer.UrlEncode(tostr(nvp.value))
				if ret = "" then
					ret = encodedNvp
				else
					ret = ret + "&" + encodedNvp
				end if
			next
		end if	
	end if
	
	return ret
	
End Function


Function HttpGetWithStatus(xfer, title="Please wait ..")
	ret = invalid
	
	port = CreateObject("roMessagePort")
	busyDialog = CreateObject("roOneLineDialog")
	busyDialog.SetMessagePort(port)
	 
	xfer.SetPort(port)
	xfer.AsyncGetToString()
	
	busyDialog.SetTitle(title)
	busyDialog.ShowBusyAnimation()
	busyDialog.Show()
	
	
	while true
		msg = WaitForEvent(0, port)
		if msg <> invalid then
			if type(msg)="roUrlEvent" then
				print tostr(msg.GetSourceIdentity()) + " =? " + tostr(xfer.GetIdentity())
				if msg.GetSourceIdentity() = xfer.GetIdentity()
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
