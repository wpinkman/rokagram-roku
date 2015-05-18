Sub PlayInstagramVideo(insta)

	StopRadio()
	
    port = CreateObject("roMessagePort")
    screen = CreateObject("roVideoScreen") 
    screen.SetMessagePort(port)
	screen.SetCertificatesFile("common:/certs/ca-bundle.crt")
	screen.InitClientCertificates()

    cmi = {}
	cmi.Stream = {}
	cmi.Stream.url = HackStripHttps(insta.videos.standard_resolution.url)
	
	if insta.user <> invalid AND insta.user.username <> invalid
		cmi.Title = insta.user.username + "'s video"
	end if
			    	
	'cmi.StreamFormat: "mp4"
	screen.SetContent(cmi)
	screen.Show()
	
	GaScreenView("video").PostAsync()
	
	ts = CreateObject("roTimeSpan")
	
	LogVideoMessage(cmi.Title, cmi.Stream.url)
	
    while true
       msg = wait(0, port)
    
       if type(msg) = "roVideoScreenEvent" then
       	   message = msg.GetMessage()
           print "showVideoScreen | msg = "; message " | index = "; msg.GetIndex()
           
           if message = "Stream started."
        	   GaTiming("ig-video", "buffering", ts.TotalMilliseconds()).PostAsync()
           end if
           
           if msg.isScreenClosed()
               print "Video screen closed"
               exit while
            else if msg.isStatusMessage()
                  print "status message: "; msg.GetMessage()
            else if msg.isPlaybackPosition()
                  print "playback position: "; msg.GetIndex()
            else if msg.isFullResult()
                  print "playback completed"
                  exit while
            else if msg.isPartialResult()
                  print "playback interrupted"
                  exit while
            else if msg.isRequestFailed()
                  ShowErrorDialog("Error playing video: " + msg.GetMessage())
                  exit while
            end if
       end if
    end while 
    	
    StartRadio()
	
End Sub