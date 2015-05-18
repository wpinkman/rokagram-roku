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
Function CreateSearchScreen() As Object
	this = {
		port: CreateObject("roMessagePort"),
		screen: CreateObject("roSearchScreen"),
		registry: CreateObject("roRegistry"),
		instareq: invalid,
		searchType: "tags",
		shouldClose: false,
		screenName: "search",
		
		Run: SearchScreenRun,
		HistoryInit: SearchScreenHistoryInit,
		
		busyDialog: CreateObject("roOneLineDialog"),
		
		Close: function() :  m.screen.Close() : m.screen = invalid : return m.screen : end function
		
		initialized: false,
	}

	this.screen.SetMessagePort(this.port)
	this.instareq = CreateInstaRequest(this.port)
	this.busyDialog.SetMessagePort(this.port)

	this.screen.SetBreadcrumbText("", "search")
	
	this.screen.SetSearchButtonText("search")
	this.screen.SetClearButtonEnabled(false)
	
	return this
End Function

Sub SearchScreenHistoryInit() 
	hasHistory = false
	hasSuggestions = false
	for each section in m.registry.GetSectionList()
		sectionName = SearchHistorySection(m.searchType)
		if section = sectionName
			regSection = CreateObject("roRegistrySection", section)
			m.suggestions = {}
			for each key in regSection.GetKeyList()
				m.screen.AddSearchTerm(key)
				uid = regSection.Read(key)
				m.suggestions[key] = {username:key,userid:uid}
	
				hasHistory = true
			next
		end if
	next
	
	if hasHistory then
		m.screen.SetSearchTermHeaderText("History:")
		m.screen.SetClearButtonText("clear history")
	else
		m.screen.SetSearchTermHeaderText("Suggestions:")
		m.suggestions = {}

		LogSearchMessage("Initializing searchtype: " + m.searchType)
		
		if m.searchType = "users"
			userSuggestions = []

			userSuggestions.Push({username:"instagram", userid:"25025320"})
			userSuggestions.Push({username:"justinbieber", userid:"6860189"})
			userSuggestions.Push({username:"kimkardashian", userid:"18428658"})
			userSuggestions.Push({username:"badgalriri", userid:"25945306"})
			userSuggestions.Push({username:"beyonce", userid:"247944034"})
			userSuggestions.Push({username:"mileycyrus", userid:"325734299"})

			userSuggestions.Push({username:"kevinhart4real", userid:"6590609"})
			userSuggestions.Push({username:"taylorswift", userid:"11830955"})
			userSuggestions.Push({username:"harrystyles", userid:"144605776"})

			
			for each suggestion in userSuggestions	
				m.screen.AddSearchTerm(suggestion.username)
				m.suggestions[suggestion.username] = {username:suggestion.username,userid:suggestion.userid}
			next
		else
			tagSuggestions = ["love", "instagood", "photooftheday", "girl", "boy", "beautiful", "instadaily", "instacat", "cute", "happy"]
			for each suggestion in tagSuggestions
				m.screen.AddSearchTerm(suggestion)
				m.suggestions[suggestion] = {username:suggestion,userid:suggestion}
			next
		end if
'		if NOT hasSuggestions
'			m.screen.SetEmptySearchTermsText("empty")
'		end if
	end if
	
	m.screen.SetClearButtonEnabled(hasHistory)
	
	m.initialized = true
		
End Sub

Function SearchScreenRun()
		
	globals = GetGlobals()
	
	if not m.initialized
		print "HistoryInit"
		m.HistoryInit()
	end if

	
    m.screen.Show()
    
    cd = m.screenName
    if m.searchType <> invalid
    	cd = cd + "-" + m.searchType
    end if
    
    GaScreenView(cd).PostAsync()
	
    globals.screenStack = []
	globals.screenStack.Push(m)
    
    while true
    	if m.shouldClose exit while
    	msg = WaitForEvent(0, m.port)
    	'msg = wait(0, m.port)
        
        if type(msg)="roUrlEvent" then
			if msg.GetInt() = 1 then
				json = msg.GetString()
				'print "respone code: " + tostr(msg.GetResponseCode())
				'print chr(10) + "response:" + json + chr(10)
				if msg.GetResponseCode() = 200 then

					parsedResponse = ParseJson(json)
					
					if instr(1, m.instareq.endpoint, "media") > 0 
						if parsedResponse.data.Count() > 0
						
							RegWrite(m.tag, m.tag, SearchHistorySection(m.searchType))

							LogShowStartMessage("Starting show '#" + m.tag + "'", m.instareq)
		        			ss = CreateInstaShowFromParsedResponse(parsedResponse)
		        			ss.nextEndpoint = m.instareq.endpoint
		        			if m.busyDialog <> invalid then 
		        				m.busyDialog.Close()
		        			end if
		        			ss.Run()
	        			else
		        			if m.busyDialog <> invalid then 
		        				m.busyDialog.Close()
		        			end if
	        				ShowErrorDialog("No Content", "No content found. Try another search string.")
	        			end if
					else
						m.suggestions = {}
						m.screen.ClearSearchTerms()
						foundOne = false
						if m.searchType = "users"
							for each suggestion in parsedResponse.data
								m.suggestions[suggestion.username] = suggestion
								m.suggestions[suggestion.username].userid = suggestion.id
								m.screen.AddSearchTerm(suggestion.username)
								foundOne = true
							next
						else if m.searchType = "tags" then
							sugCount = 0
							for each suggestion in parsedResponse.data
								'suggestions[suggestion.username] = suggestion
								'suggestions[suggestion.username].userid = suggestion.id
								print tostr(sugCount) + ": " + suggestion.name
								if suggestion.name <> invalid then
									m.screen.AddSearchTerm(suggestion.name)
									foundOne = true
								else
									print "ERROR: suggestion.name is invalid"
								end if
								sugCount = sugCount + 1
								if sugCount > 10 
									exit for
								end if
							next
						end if
						if foundOne then
							m.screen.SetSearchTermHeaderText("Suggestions:")
						end if
					end if
					'print "Received " + Stri(m.contentArray.Count()) + " photos.. on with the show"
				else
        			if m.busyDialog <> invalid then 
        				m.busyDialog.Close()
        			end if
        			if msg.GetResponseCode() <> -10001
	        			ShowErrorDialog(msg.GetFailureReason(), "Unexpected Error.  Please try again later.")
						print "ERROR: unextected return code: " + Stri(msg.GetResponseCode()) + ", reason:" + msg.GetFailureReason()
					end if
				end if
			end if
		else if type(msg) = "roSearchScreenEvent"
            if msg.isScreenClosed()
                exit while
            else if msg.isCleared()
                m.screen.ClearSearchTerms()
                ClearSearchHistory(m.searchType)
                m.HistoryInit()
            else if msg.isPartialResult()
                
                if msg.GetMessage() = "" then
					m.suggestions = {}
					m.screen.ClearSearchTerms()
                else 
                	m.instareq.xfer.AsyncCancel()
	                
                	q = msg.GetMessage()
                	if Instr(0, q, " ") > 0
	                	q = strReplace(q, " ", "_")
	                	m.screen.SetSearchText(q)
                	end if
                	
                	if Len(q) > 3
	                	m.instareq.url = invalid
		                m.instareq.endpoint = "/" + m.searchType + "/search"
		                m.instareq.AddQueryParam("q",q)
		                m.instareq.AddQueryParam("count", "9")
		                m.instareq.StartGetToString()
		            else 
		            	print "q too short.. don't bother q:" + q
	                end if
                end if
                    
                
            else if msg.isFullResult()
                
            	message = msg.GetMessage()
                if message <> "" then
                
                	LogSearchMessage("Searching '" + message + "'")
                
                	if m.searchType = "users" then
		                
                		usedSuggestion = false
		                if m.suggestions <> invalid
		                	searchedUser = m.suggestions[msg.GetMessage()]
		                	if searchedUser <> invalid
				                print searchedUser.username + ", id:" + searchedUser.userid
				                
			                	RegWrite(searchedUser.username, searchedUser.userid, SearchHistorySection(m.searchType))
				                
		                		searchedUser.id = searchedUser.userid
				                uspringScreen = CreateUserSpringBoardScreen(searchedUser)
				                uspringScreen.Run()
				                usedSuggestion = true
				             end if
		                end if
		                if NOT usedSuggestion
		                	port = CreateObject("roMessagePort")
		                	sr = CreateInstaRequest(port)
			                sr.endpoint = "/users/search"
			                sr.AddQueryParam("q",msg.GetMessage())
			                sr.AddQueryParam("count", "25")
			                sr.BuildUrl()
			                msg = HttpGetWithStatus(sr.xfer, "Searching...")
			                json = msg.GetString()
					
			                'print chr(10) + "response:" + json + chr(10)

			                parsedResponse = ParseJson(json)
			                if parsedResponse.meta.code = 200
			                	if parsedResponse.data.Count() > 0
									screen = CreateUsersPoster()
									screen.RunSearchResults(parsedResponse)
			                	else
			                		ShowErrorDialog("No results returned.  Try a different search string.", "No Results")
			                	end if
			                else
			                	ShowErrorDialog("There was an error with this search.  Please try again.","Error")
			                end if
		                end if
	                else if m.searchType = "tags" then
	                	tag = msg.GetMessage()
	                	m.instareq.url = invalid
	                	xfer = CreateObject("roUrlTransfer")
	                	m.instareq.endpoint = "/tags/" + xfer.Escape(tag) + "/media/recent"
	                	m.instareq.ClearParams()
	                	
			            m.tag = tag
			            
	                	if globals.saver
	                		desc = "#" + tag
	                		t = "Search"
			    			WriteScreenSaver("type", t)
			    			WriteScreenSaver("description", desc)
	                		m.instareq.BuildUrl()
			    		    WriteScreenSaver("url", m.instareq.url)
			    		    RegWrite(m.tag, m.tag, SearchHistorySection(m.searchType))
			    		    
			    		    ShowScreenSaverSetDialog(desc)
			    		    LogScreenSaverMessage(t + " : " + desc, m.instareq.url)
			    		    m.screen.Close()
			    		    return 1
	                	else
			                m.instareq.StartGetToString()
		    				m.busyDialog.SetTitle("Loading #" + msg.GetMessage())
		    				m.busyDialog.ShowBusyAnimation()
		    				m.busyDialog.Show()
	    				end if
	                end if
                end if
                
            else
                print "Unknown event: "; msg.GetType(); " msg: ";msg.GetMessage()
            endif
        endif
    end while 
    return 0
End Function
