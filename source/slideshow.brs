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

Function CreateSlideShow(settings = invalid) As Object
	this = {
	
		ss: CreateObject("roSlideShow"),
		http: CreateHttpRequest(),
		port: CreateObject("roMessagePort"),
	    facade: CreateObject("roImageCanvas"),
		
		' state
		playbackPosition: 0,
		paused: false,
		buttons: invalid,
		
		contentArray: invalid,
		settings: settings,
		useRokagramTitleSlide: true,
		
		ProcessEvents: SlideShowProcessEvents,
		SetContentArray: SetContentArray,
		AddButton: SlideShowAddButton,
		ClearButtons: SlideShowClearButtons,
		
		Run: SlideShowRun,
		
		OnPause: SlideShowOnPause,
		
		ContentCount: function() : return m.contentArray.Count() : end function
		GetOnscreen: function() : return m.contentArray[m.playbackPosition] : end function
		'HasTitleSlide: function() : return type(m.settings.titleSlide) = "roAssociativeArray" :end function,
		Close: SlideShowClose
		
	}

	this.facade.SetBackgroundColor("#00000000")
	this.facade.SetLayer(0, {Color:"#FF000000", CompositionMode:"Source"})
	facadeMessage = "Loading"
	if settings.title <> invalid then
		facadeMessage = facadeMessage + " " + settings.title + " "
	end if
	facadeMessage = facadeMessage + "..."
	this.facade.SetLayer(1, {text : facadeMessage, TextAttrs:{Color:"#FFCCCCCC", Font:"Large"}})

    this.ss.SetMessagePort(this.port)
	this.http.SetMessagePort(this.port)

	
	if settings <> invalid then
		if settings.displayMode <> invalid then 
			this.ss.SetDisplayMode(settings.displayMode) 
		end if
		if settings.period <> invalid then
			this.ss.SetPeriod(settings.period)
		else 
			this.ss.SetPeriod(5)
		end if
		
		if settings.userid <> invalid then
			print "SlideShow setting userid:" + settings.userid
			this.http.SetUserid(settings.userid)
		end if
	end if
		
	
	return this
	
End Function

Sub SlideShowClose()
	m.ss.Close()
	m.facade.Close()
	m.facade = invalid
	m.http.Close()
	m.port = invalid
	m.ss = invalid
End Sub

Sub SetContentArray(contentArray As Object)
		

		count = 0
		for each contentItem in contentArray
			if contentItem.tagList.count() > 0 then
				contentItem.TextOverlayUR = "Browse Tags -> Nav Down"
			end if
			print Stri(count) + "::" + contentItem.username
			count = count + 1
		next

		m.contentArray = contentArray
		m.ss.SetContentList(m.contentArray)
		m.ss.SetNext(0, true)
		
End Sub

Sub SlideShowAddButton(button)
	if m.buttons = invalid then
		m.buttons = []
	end if
	
	m.buttons.Push(button)
	m.ss.AddButton(m.buttons.Count() - 1, button.title)
	
End Sub

Sub SlideShowClearButtons()
	m.ss.ClearButtons()
	m.buttons = invalid
End Sub

Sub SlideShowRun()
	
	if type(m.settings.noloading) = "Invalid" then
		m.facade.Show()
	end if
	
	m.http.xfer.SetUrl(m.settings.server + m.settings.path)
	m.http.xfer.AsyncGetToString()
	
	m.ProcessEvents()
		
End Sub

Function SlideShowProcessEvents()

	while true

		msg = wait(0, m.port)
		
		if type(msg)="roUrlEvent" then
			if msg.GetInt() = 1 then
				if msg.GetResponseCode() = 200 then
					json = msg.GetString()
					m.SetContentArray(ParseJson(json))
					'print "Received " + Stri(m.contentArray.Count()) + " photos.. on with the show"
					m.ss.Show()
					m.facade.Close()
				else
					print "ERROR: unextected return code: " + Stri(msg.GetResponseCode()) + ", reason:" + msg.GetFailureReason()
				end if
			end if
		
		else if type(msg)="roSlideShowEvent" then
			'print "roSlideShowEvent. Type ";msg.GetType();", index ";msg.GetIndex();", Data ";msg.GetData();", msg ";msg.GetMessage()
		
			if msg.isScreenClosed() then
				print "roSlideShowEvent::ScreenClosed"
				'm.Close()
				return 0
			else if msg.IsPaused() then
				m.OnPause()
			else if msg.isRemoteKeyPressed() then
				print "roSlideShowEvent::RemoteKeyPressed, index:" + Stri(msg.GetIndex()) + ", paused:" + ToString(m.paused)
				
				if msg.GetIndex()=3 and m.ss.CountButtons()=0 then
				
					if m.paused then
						meta = m.getOnscreen()
						'm.AddButton({title:"@" + meta.username, userid:meta.userid})
				
						count = 0
						for each tag in meta.tagList
							btnLabel = "#" + tag
							print Stri(count) + " : adding button: " + btnLabel
							m.AddButton({title:btnLabel, tag:tag})
							if count > 2 then
								print "too many tags"
								exit for
							end if
							count = count + 1
						next
						print "added " + Stri(count) + " buttons"
						if count > 0 then
							m.AddButton({title:"Cancel"})
							print "added cancel button"
						end if
					else
						m.ss.Pause()
						m.OnPause()
					end if
				end if
		
			else if msg.IsResumed() then
				print "roSlideShowEvent::Resumed"
				m.ss.SetTextOverlayIsVisible(false)
				m.ss.ClearButtons()
				m.paused = false
			else if msg.isButtonPressed() then
				buttonCount = m.ss.CountButtons()
				print "roSlideShowEvent::ButtonPressed index:" + Stri(msg.GetIndex()) + " buttonCount:" + Stri(buttonCount)
				
				
'				m.ss.Resume()
'				m.paused = false
				
				if msg.GetIndex() < (buttonCount - 1) then
					button = m.buttons[msg.GetIndex()]
					
					'if button.userid <> invalid then
					'	m.ss.ClearButtons()
					'	m.settings.path = "/api/users/" + button.userid
					'	ss = CreateSlideShow(m.settings)
				'		m.Close()
					'	ss.Run()
					'end if
					
					if button.tag <> invalid then
						m.ss.ClearButtons()
						m.settings.path = "/api/tags/" + button.tag
						m.settings.title = button.title
						ss = CreateSlideShow(m.settings)
						m.Close()
						ss.Run()
						return 0
					end if
					
				else
					print "cancel"
					m.ss.ClearButtons()
					m.buttons.Clear()
				end if
				
			else if msg.isPlaybackPosition()
				
				changed = m.playbackPosition <> msg.GetIndex()
				m.playbackPosition = msg.GetIndex()
				
				if changed then
					
					print "roSlideShowEvent::PlaybackPosition::" + Stri(m.playbackPosition) + "::" Stri(m.playbackPosition + 1) + " of " + Stri(m.ContentCount()) + " shared by " + m.getOnscreen().TextOverlayUL
					
					if msg.GetIndex() = m.ContentCount() - 1 then
						if not m.paused then
							'm.settings.title = "more"
							m.settings.noloading = true
							ss = CreateSlideShow(m.settings)
							ss.Run()
							m.Close()
						end if
					end if
				end if
				
			else if msg.isRequestSucceeded()
				'print "roSlideShowEvent::RequestSucceeded::" + Stri(msg.GetIndex())

				
			else if msg.isRequestFailed()
				print "roSlideShowEvent::RequestFailed::" + Stri(msg.GetIndex())
			else if msg.isRequestInterrupted()
				print "roSlideShowEvent::RequestInterrupted::" + Stri(msg.GetIndex())
			end if
		else
			print "WARNING received event type:" + type(msg)
			if msg = invalid then
				print "Bailing!"
				return 0
			end if
		end if
	end while
		
	return 0
	
End Function

Sub SlideShowOnPause()
	print "roSlideShowEvent::Paused"
	m.ss.SetTextOverlayIsVisible(true)
	m.paused = true
End Sub
