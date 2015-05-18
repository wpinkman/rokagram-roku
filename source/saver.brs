' *********************************************************
' *********************************************************
' **
' **  Rokagram Channel
' **
' **  W. Pinkman, February 2015
' **
' **  Copyright (c) 2015 Fugue State, Inc., All Rights Reserved.
' **
' *********************************************************
' *********************************************************
Function CreateScreenSaver() As Object
	this = {
		port: invalid,
		canvas: invalid,
		instareq: invalid,
		
		thumbs: CreateObject("roArray", 20, false),
		currentData: CreateObject("roArray", 20, false),
		nextData: CreateObject("roArray", 20, false),
		
		itemHash: CreateObject("roAssociativeArray"),
		
		next_url: invalid,
		max_timestamp: invalid,
		saverType: "Beautiful",
		description: "Beauty on Instagram",
		
		btnChangeFeed: 0,
		btnChangeBanner: 1,
		btnPreview: 2,
		btnClose: 3,
		
		banner: invalid,
		
		InitLayout: ScreenSaverInitLayout,
		GetData: ScreenSaverGetData,
		FetchData: ScreenSaverFetchData,
		WaitForHttp: ScreenSaverWaitForHttp,
		
		Run: ScreenSaverRun,
		RunSettings: ScreenSaverRunSettings,
		ReadRegistry: ScreenSaverReadRegistry,
		ShowKeyboardScreen: ScreenSaverShowKeyboardScreen
	}

	this.InitLayout()
	
	return this
	
End Function


Sub ScreenSaverRun()

	LogStartupMessage("ScreenSaver")
	
	globals = GetGlobals()

	m.port = CreateObject("roMessagePort")
	m.canvas = CreateObject("roImageCanvas")

	m.canvas.SetMessagePort(m.port)
	
	m.canvas.SetCertificatesFile("common:/certs/ca-bundle.crt")
	m.canvas.InitClientCertificates()
	
	
	m.canvas.SetRequireAllImagesToDraw(true)
	m.canvas.SetLayer(0, {Color:"#FF000000", CompositionMode:"Source"})
	m.canvas.SetLayer(1, {Text:"Loading."})
	
	m.canvas.Show()
	GaScreenView("saver").SetSessionStart().PostAsync()
	
	m.ReadRegistry()
	
	reqUrl = invalid
	count = 0
	
	crect = m.canvas.GetCanvasRect()
	
	while true
	
		data = m.GetData()
		
		print "GetData returned " + Stri(data.Count()) + " items"
		if (data.Count() = 0) 
			exit while
		end if
		
		test = {}
		for each item in data
			if test.DoesExist(item.id)
				print "ERROR"
				print "ERROR duplicate id " + item.id
				print "ERROR"
			else
				test[item.id] = item.id
			end if
		next
		
		thumbContentList = []
		for i = 0 to data.Count() - 1
			item = data[i]
			if i < m.thumbs.Count()
				imgUrl = HackStripHttps(item.images.thumbnail.url)
				thumbContentList.Push({Url:imgUrl, TargetRect:m.thumbs[i], CompositionMode:"Source"})
			end if
		next
				
		rcount = 0
		for each item in data
			if NOT globals.saverTest OR (rcount < 2 OR rcount > 17) OR data.Count() < 18
				imgUrl = HackStripHttps(item.images.standard_resolution.url)
				if crect.w = 1280
				
					trec = {x:320,y:40,w:640,h:640}
					if m.banner <> invalid
						xoff = 320
						width = 640
						m.canvas.SetLayer(6, {Color:"#80000000", TargetRect:{x:xoff,y:640,w:width,h:640}, CompositionMode:"SourceOver"})
						m.canvas.SetLayer(7, {Text:m.banner, TargetRect:{x:xoff+10,y:640,w:width,h:40}, TextAttrs:{ 
							Color:"#FFCCCCCC", 
							Font:"Medium", 
							HAlign:"Center", 
							VAlign:"Middle" }} )
					end if
				
					m.canvas.SetLayer(2, {Url:imgUrl, TargetRect:trec, CompositionMode:"Source"})
					tc = thumbContentList[rcount]
					m.canvas.SetLayer(3, thumbContentList)
					m.canvas.SetLayer(4, {Color:"#80000000", TargetRect:tc.TargetRect, CompositionMode:"SourceOver"})
				else
					m.canvas.SetLayer(2, {Url:imgUrl, TargetRect:{x:120,y:0,w:480,h:480}, CompositionMode:"Source"})
					if m.banner <> invalid
						width = 480
						m.canvas.SetLayer(6, {Color:"#80000000", TargetRect:{x:120,y:440,w:width,h:40}, CompositionMode:"SourceOver"})
						m.canvas.SetLayer(7, {Text:m.banner, TargetRect:{x:130,y:440,w:width,h:40}, TextAttrs:{ 
							Color:"#FFFFFFFF", 
							Font:"Medium", 
							HAlign:"Center", 
							VAlign:"Middle" },CompositionMode:"SourceOver"} )
					end if
				end if
				
				print "showing " + tostr(count) + ", " + tostr(rcount) + " of " + tostr(data.Count()) + " " + item.id
				
				m.canvas.Show()
				
				msg = WaitForEvent(6000, m.port)
				
				if msg <> invalid
					print "got message type " + type(msg) + " exiting..."
					m.canvas.Close()
					exit while
				end if
			else
				print "skipping " + tostr(count) + ", " + tostr(rcount) + " of " + tostr(data.Count())  
			end if
			
			rcount = rcount + 1
			count = count + 1
						
		next
		
		m.canvas.PurgeCachedImages()
		RunGarbageCollector()
		
		if count > 99
			m.next_url = m.base_url
			m.max_timestamp = invalid
			count = 0
		end if
		
		GaEvent("screensaver", "rollover", invalid, count).PostAsync()
	
	end while
		
End Sub

Sub ScreenSaverInitLayout()
					
	thumbx = 124
	thumby = 124
	fatmargin = 0
	
	xoffs = CreateObject("roArray", 4, false)
	xoffs.Push(320 - 5 - thumbx - 5 - thumbx - fatmargin)
	xoffs.Push(320 - 5 - thumbx - fatmargin)
	xoffs.Push(320 + 640 + 5 + fatmargin)
	xoffs.Push(320 + 640 + 5 + thumbx + 5 + fatmargin)
	
	yoffs = CreateObject("roArray", 5, false)
	yoffs.Push(40)
	yoffs.Push(40 + thumby + 5)
	yoffs.Push(40 + thumby + 5 + thumby + 5)
	yoffs.Push(40 + thumby + 5 + thumby + 5 + thumby + 5)
	yoffs.Push(40 + thumby + 5 + thumby + 5 + thumby + 5 + thumby + 5)
	
	for r = 0 to yoffs.Count() - 1
		for c = 0 to xoffs.Count() - 1
			m.thumbs.Push({x:xoffs[c], y:yoffs[r] ,w:thumbx,h:thumby})
		next
	next

End Sub

Function ScreenSaverGetData() As Object

	m.currentData.Clear()
	m.itemHash.Clear()
	
	m.fetchDepth = 0
	print "=========== CALLING FETCH DATA ==================="
	m.FetchData()
	
	return m.currentData
	
End Function
	
Sub ScreenSaverFetchData() As Object

	globals = GetGlobals()
	
	print "FetchData depth:" + tostr(m.fetchDepth)
	m.fetchDepth = m.fetchDepth + 1
	
	if m.nextData.Count() > 0
		print tostr(m.nextData.Count()) + " items left over"
		for each item in m.nextData
			m.currentData.Push(item)
			m.itemHash[item.id] = item.id
		next
	end if
	
	m.nextData.Clear()
	
	ret = invalid
	
	ireq = CreateInstaRequest(m.port)
	
	if m.next_url <> invalid
		ireq.url = m.next_url
	else
		ireq.endpoint = globals.feeds.beauty.endpoint
		ireq.access_token = globals.feeds.beauty.access_token
	end if
	
	ireq.StartGetToString()
	json = m.WaitForHttp()
	
	m.next_url = invalid
	
	if json <> invalid
		parsedResponse = ParseJson(json)
		if parsedResponse <> invalid
			if parsedResponse.meta.code = 200
				
				print tostr(parsedResponse.data.Count()) + " items returned"
				m.canvas.SetLayer(1, {Text:"Loading.."})
				
				for each item in parsedResponse.data
					
					m.max_timestamp = item.created_time
					
					if m.currentData.Count() < 20
						if NOT m.itemHash.DoesExist(item.id)
							m.itemHash[item.id] = item.id
							print tostr(m.currentData.Count()) + " :: " + item.id + ":: adding current item posted by " + item.user.username + " at " + item.created_time
							m.currentData.Push(item)
						else 
							print "Skipping item " + item.id
						end if
					else if m.nextData.Count() < 20
						if NOT m.itemHash.DoesExist(item.id)
							m.itemHash[item.id] = item.id
							print tostr(m.nextData.Count()) + " :: " + item.id + ":: adding next item posted by " + item.user.username + " at " + item.created_time
							m.nextData.Push(item)
						else 
							print "Skipping (next) item " + item.id
						end if
						
					else
						print "ERROR too much data!!"
						exit for
					end if
				next
				
				if m.base_url = invalid
					m.base_url = ireq.url
				end if
				
				if parsedResponse.pagination <> invalid AND parsedResponse.pagination.next_url <> invalid
					m.next_url = parsedResponse.pagination.next_url
				else
					if Instr(1, ireq.url, "/media/search") > 0 AND m.max_timestamp <> invalid
						print "this is a search url, use max date??"
						m.next_url = m.base_url + "&max_timestamp=" + m.max_timestamp.Trim()
					else
						m.next_url = m.base_url
					end if
				end if
				print "next_url:" + m.next_url
				
				if m.currentData.Count() < 20 AND m.fetchDepth < 3
					print "Calling fetch data recursively m.currentData.Count() = " + tostr(m.currentData.Count())
					m.FetchData()
				else
					print "Done fetching data current / next = " + tostr(m.currentData.Count()) + " / " + tostr(m.nextData.Count())
				end if
				
			else
				print "Bad return code: " + json
			end if
		else
			print "invalid parsed Response"
			print json
		end if
	else
		print "invalid json"
	end if
	
End Sub			
					
Sub ScreenSaverRunSettings()
		
	LogStartupMessage("ScreenSaverSettings")
	
	globals = GetGlobals()
		
	prevScreen = invalid
	screen = invalid
	
	while true
		m.ReadRegistry()
		
		prevScreen = screen
		
		port = CreateObject("roMessagePort")
		screen = CreateObject("roParagraphScreen")
		screen.SetMessagePort(port)
		
		screen.AddHeaderText("Screen Saver Settings")
		screen.AddParagraph("Choose an Instagram feed to use for your screen saver")
		'if user.profile_picture <> invalid
		'	screen.AddGraphic(user.profile_picture)
		'end if
		
		screen.AddParagraph("Current feed: " + m.saverType + " (" + m.description + ")")
		banner = m.banner
		if banner = invalid
			banner = "none set"
		end if
		screen.AddParagraph("Current Banner: " + banner)
		
		screen.AddButton(m.btnChangeFeed, "Change Feed")
		if globals.deviceInfo.displayMode = "720p"
			screen.AddButton(m.btnChangeBanner, "Change Banner")
		end if
		screen.AddButton(m.btnPreview, "Preview")
		screen.AddButton(m.btnClose, "Close")
		screen.Show()
		
		GaScreenView("settings").PostAsync()
		
		if prevScreen <> invalid
			prevScreen.Close()
		end if
		
	    msg = WaitForEvent(0, screen.GetMessagePort())
	
	    if type(msg) = "roParagraphScreenEvent"
	        if msg.isScreenClosed()
	            print "Screen closed"
	            exit while                
	        else if msg.isButtonPressed()
	        	btnIndex = msg.GetIndex()
	            if btnIndex = m.btnChangeFeed
	            
		        	posterScreen = CreatePosterScreen()
		        	posterScreen.Show()
		        	posterScreen.Run()
		        else if btnIndex = m.btnChangeBanner
		        	m.ShowKeyboardScreen()
		        else if btnIndex = m.btnPreview
		        	m.Run()
	            else
		            exit while
	            end if
	        else
	            print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
	            exit while
	        endif
	    endif
	end while
End Sub

Sub ScreenSaverShowKeyboardScreen()  

	screen = CreateObject("roKeyboardScreen")
	port = CreateObject("roMessagePort") 
	screen.SetMessagePort(port)
	screen.SetMaxLength(40)
	if m.banner <> invalid
		screen.SetText(m.banner)
	end if
	screen.SetDisplayText("enter text for banner")
	screen.AddButton(1, "Done")
	screen.AddButton(2, "Clear")
	screen.AddButton(3, "Back")
	screen.Show()
	GaScreenView("keyboard").PostAsync()
	
	while true
	    msg = WaitForEvent(0, screen.GetMessagePort()) 
	    print "message received"
	    if type(msg) = "roKeyboardScreenEvent"
	        if msg.isScreenClosed()
	            exit while
	        else if msg.isButtonPressed() then
	            print "Evt:"; msg.GetMessage ();" idx:"; msg.GetIndex()
	            if msg.GetIndex() = 1
	                text = screen.GetText()
	                print "search text: "; text 
	                if text = ""
	                	print "text empty, returning invalid"
	                	text = invalid
	                end if
		        	WriteScreenSaver("banner", text)
	                exit while
	            else if msg.GetIndex() = 2
	            	screen.SetText("")
		        	WriteScreenSaver("banner", invalid)
	            else
	            	exit while
	            end if
	        endif
	    endif
	 end while
	
End Sub

Sub ScreenSaverReadRegistry()
	saverType = ReadScreenSaver("type")
	if saverType <> invalid
		m.saverType = saverType
	end if
	
	url = ReadScreenSaver("url")
	if url <> invalid
		m.next_url = url
	end if
	
	desc = ReadScreenSaver("description")
	if desc <> invalid
		m.description = desc
	end if
	
	m.banner = ReadScreenSaver("banner")

End Sub
					

Function ScreenSaverWaitForHttp()

	ret = invalid
	
	msg = wait(0, m.port)
	
	if type(msg)="roUrlEvent" then
		gi = msg.GetInt()
		if gi = 1 then
			ret = msg.GetString()
		else
			print "ERROR gi:" + Stri(gi)
		end if
	end if
	
	return ret

End Function 
