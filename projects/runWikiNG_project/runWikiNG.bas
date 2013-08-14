' runWikiNG
'
' By Neal Collins (www.staddle.net)
' Based on runWiki by Carl Gundel of Shoptalk Systems

' *******************************************
' ** CHANGE THESE VALUES TO SUIT YOUR SITE **
' *******************************************

' Set this to the application name
AppName$ = "runWikiNG"

' If non-zero, allow new sites to be defined on the fly
newSites = 0

' If non-zero, allow admins to create new sites
adminNewSites = 1

' Location used to store runWikiNG databases
' DatabaseDir$ = DefaultDir$ ' Use this for compatibility with older versions
DatabaseDir$ = DefaultDir$ + pathSeparator$ + AppName$

' ***************************************
' ** END OF USER CONFIGURATION SECTION **
' ***************************************

global Site$, adminNewSites
global pathSeparator$, siteUrl$, baseUrl$, dateFormat$
global AppName$, DatabaseDir$, DatabaseFilename$, uploadDir$, themeDir$, cssFile$
global siteName$, siteDesc$, allowRegistration, allowObjects, allowPlugins, allowUploads, showBreadcrumbs, siteTheme$, newWindow
global userDB$
global errorMessage$, successMessage$
global PostBlockHTML$

if Platform$ = "unix" then
  pathSeparator$ = "/"
else
  pathSeparator$ = "\"
end if

Site$ = getUrlParam$("site")
if Site$ = "" then Site$ = AppName$

DatabaseFilename$ = DatabaseDir$ + pathSeparator$ + Site$ + ".db"

if newSites = 0 and Site$ <> AppName$ then
  ' Check that database file already exists
  files #site, DatabaseFilename$
  if not(#site hasAnswer()) then
    cls
    head "<link href=""/"; AppName$; "/bootstrap/css/bootstrap.min.css"" rel=""stylesheet""/>"
    html "</div><div class=""container-fluid""><br/>"
    html "<div class=""alert alert-block alert-error"">"
    html "<h4>Unknown Site - "
    print Site$;
    html "</h4>"
    html "<p>The site you are trying to visit does not exist and the creation of new sites has been disabled.</p>"
    html "</div></div><div>"
    end
  end if
end if

dim breadcrumbs$(10)
breadcrumbs$(0) = "Home"

global currentName$, currentContent$, newContent$, sidebarContent$, newSidebarContent$, pageTimestamp$, pageUpdateBy$, pageLocked
global #editPage, #db, #user, #userList
global preview, hideFlag
global #searchText, searchText$, pageDeleted
global numInlineTags
global #blockStack, #tagStack, #htmlStack
global smtpHost$, smtpPassword$, fromAddress$
global PluginParams$
global lightboxScript

dim inlineTag$(50, 4)

global filecount

dim fileNames$(500)
dim fileSizes(500)
dim fileTimes$(500)

on error goto [handleError]

run #user, "userObject"
run #userList, "userObject"

uploadDir$ = ResourcesRoot$ + pathSeparator$ + Site$
themeDir$ = ResourcesRoot$ + pathSeparator$ + AppName$ + pathSeparator$ + "bootstrap" + pathSeparator$ + "css"

call createDirectories
call createDatabase

call loadWikiTags
call createStacks

[bootSite]
call loadSite

if siteName$ = "" then
  goto [setupUserDB]
else
  if userDB$ <> "" then
    userdbFilename$ = DefaultDir$ + pathSeparator$ + userDB$
    #user setDatabaseName(userdbFilename$)
    #userList setDatabaseName(userdbFilename$)
  end if
end if

name$ = getUrlParam$("page")
if name$ = "" then name$ = "Home"
call loadPage name$
wait

[cancel]
  userAdmin = 0
  call displayCurrentPage
  wait

[logout]
  #user logout()
  successMessage$ = "You have been logged out."
  call displayCurrentPage
  wait

' ======================
' ==== LOGIN SCREEN ====
' ======================

[login]
  call adminHeading "Login"
  html "<div class=""alert alert-info"">Please login using either your username or email address.</div>"
  if allowRegistration then
    html "<div class=""alert"">"
    print "If you do not have an account, you can request one by clicking ";
    link #register, "here", [register]
    print ".";
    html "</div>"
  end if
  if errorMessage$ = "" then
    username$ = ""
  else
    call displayMessages
  end if
  html "<label class=""required"">Username or Email Address</label>"
  textbox #username, username$
  #username setfocus()
  html "<label>Password</label>"
  passwordbox #password, ""
  html "<div class=""form-actions"">"
  button #login, "Log in", [doLogin]
  #login cssclass("btn btn-success")
  html " "
  button #cancel, "Cancel", [cancel]
  #cancel cssclass("btn")
  html " "
  link #forgotPassword, "Forgot Password", [forgotPassword]
  #forgotPassword cssclass("btn")
  html "</div></div>"
  call adminFooter
  wait

[doLogin]
  username$ = #username contents$()
  if (#user login(username$, #password contents$()) = 0) then
    errorMessage$ = #user errorMessage$()
    goto [login]
  end if

  call displayCurrentPage
  wait

[forgotPassword]
  call adminHeading "Forgot Password"
  if errorMessage$ = "" then
    email$ = ""
  else
    call displayMessages
  end if
  html "<p>Enter your user name or email address. Your password will be reset and emailed to your email address.</p>"
  html "<label class=""required"">Username or Email Address</label>"
  textbox #email, email$
  #email setfocus()
  html "<div class=""form-actions"">"
  button #reset, "Reset Password", [resetPassword]
  #reset cssclass("btn btn-accept")
  html " "
  button #cancel, "Cancel", [cancel]
  #cancel cssclass("btn")
  html "</div>"
  call adminFooter
  wait

[resetPassword]
  if #user lostPassword(#email contents$()) = 0 then
    errorMessage$ = #user errorMessage$()
    goto [forgotPassword]
  end if

  call adminHeading "Password Reset"
  html "<div class=""alert alert-block alert-success"">"
  html "<h4>Password Reset</h4>"
  html "<p>Your password has been successfully reset. The new password has been emailed to you.</p><p>"
  button #continue, "Continue", [cancel]
  #continue cssclass("btn")
  html "</p></div>"
  call adminFooter
  wait

' ====================
' ==== NAVIAGTION ====
' ====================

[createPage]
  if #user id() <> 0 then
    currentName$ = EventKey$
    call addBreadcrumb currentName$
    newPage = 1
    goto [editPage]
  else
    call loadPage EventKey$
  end if
  wait

' =======================
' ==== SPECIAL PAGES ====
' =======================

[index]
  save$ = currentName$
  currentName$ = "Page Index"
  call displayCurrentPage
  currentName$ = save$
  wait

[recent]
  save$ = currentName$
  currentName$ = "Recent Changes"
  call displayCurrentPage
  currentName$ = save$
  wait

[startSearch]
  searchText$ = #searchText contents$()
  if searchText <> "" then
    save$ = currentName$
    currentName$ = "Search Results"
    call displayCurrentPage
    currentName$ = save$
  end if
  wait

[findHashTag]
  searchText$ = "#" + EventKey$
  save$ = currentName$
  currentName$ = "Search Results"
  call displayCurrentPage
  currentName$ = save$
  wait

[gotoPage]
  call adminHeading "Go To Page"
  call displayMessages
  html "<div class=""form-inline"">"
  html "<fieldset><legend>Go to page</legend>"
  html "<p class=""text-info"">Use this form to go directly to a page. If the page does not exist, you will be able to create it.</p>"
  html "<label class=""required"">Page name</label> "
  textbox #name, ""
  #name setfocus()
  html " "
  button #go, "Go", [acceptGotoPage]
  #go cssclass("btn btn-success")
  html " "
  button #cancel, "Cancel", [cancel]
  #cancel cssclass("btn")
  html "</fieldset></div>"
  call adminFooter
  wait

[acceptGotoPage]
  name$ = trim$(#name contents$())
  if name$ = "" then
    errorMessage$ = "Please enter a page name."
    goto [gotoPage]
  end if
  call loadPage name$
  wait

[renamePage]
  call adminHeading "Rename Page - "; currentName$
  call displayMessages
  html "<div class=""form-inline"">"
  html "<fieldset><legend>Rename Page - "
  print currentName$;
  html "</legend> "
  html "<p class=""text-info"">Use this form to rename a page. Note that links to the page are <b>not</b> updated.</p>"
  html "<label class=""required"">Page name</label> "
  textbox #name, currentName$
  #name setfocus()
  html " "
  button #go, "Rename", [acceptRenamePage]
  #go cssclass("btn btn-success")
  html " "
  button #cancel, "Cancel", [cancel]
  #cancel cssclass("btn")
  html "</fieldset></div>"
  call adminFooter
  wait

[acceptRenamePage]
  name$ = trim$(#name contents$())
  if name$ = "" then
    errorMessage$ = "Please enter a page name."
    goto [renamePage]
  end if
  call connect
  if upper$(name$) <> upper$(currentName$) then
    #db execute("select 1 from pages where upper(name) = upper("; quote$(name$); ")")
    if #db hasanswer() then
      call disconnect
      errorMessage$ = "Page named """; name$; """ already exists."
      goto [renamePage]
    end if
  end if
  #db execute("update pages set name = "; quote$(name$); " where upper(name) = upper("; quote$(currentName$); ")")
  #db execute("update page_history set name = "; quote$(name$); " where upper(name) = upper("; quote$(currentName$); ")")
  call disconnect

  call loadPage name$
  wait

'
' Recover a deleted page
'
[recoverPage]
  call connect
  #db execute("select distinct name as name from page_history where upper(name) not in (select upper(name) from pages)")
  if not(#db hasanswer()) then
    call disconnect
    call adminHeading "Recover Deleted Page"
    html "<div class=""alert alert-error alert-block"">"
    html "<h4>Recover Deleted Page></h4>"
    html "<p>No deleted pages found.</p>"
    button #continue, "Continue", [cancel]
    #continue cssclass("btn")
    html "</div>"
    call adminFooter
    wait
  end if

  dim deletedPages$(#db rowcount())
  deletedPages$(0) = "-- Select page to recover --"
  for i = 1 to #db rowcount() - 1
    #row = #db #nextrow()
    deletedPages$(i) = #row name$()
  next i
  call disconnect

  call adminHeading "Recover Deleted Page"
  call displayMessages
  html "<div class=""form-inline"">"
  html "<fieldset><legend>Recover Deleted Page</legend>"
  html "<p class=""text-info"">Use this form to recover a page which has been deleted.</p>"
  html "<label class=""required"">Page name</label> "
  listbox #name, deletedPages$(), 1
  html " "
  button #go, "Recover", [acceptRecoverPage]
  #go cssclass("btn btn-success")
  html " "
  button #cancel, "Cancel", [cancel]
  #cancel cssclass("btn")
  html "</fieldset></div>"
  call adminFooter
  wait

[acceptRecoverPage]
  name$ = trim$(#name selection$())
  if name$ = "-- Select page to recover --" then
    errorMessage$ = "Please select a page to recover."
    goto [recoverPage]
  end if
  call connect
  #db execute("insert into pages select * from page_history where upper(name) = upper("; quote$(name$); ") order by date desc, time desc limit 1")
  call disconnect

  call loadPage name$
  wait

' ==========================
' ==== EDIT PAGE SCREEN ====
' ========================== 

[previewEditPage]
  newContent$ = #content contents$()
  newSidebarContent$ = #sidebar contents$()
  newHideFlag = #hide value()

  preview = 1

[editPage]
  ' Get list of pages
  call connect
  #db execute("select name from pages order by case when upper(name) = 'HOME' then 0 else 1 end, upper(name)")
  if #db hasanswer() then
    dim pages$(#db rowcount())
    for i = 1 to #db rowcount()
      #row = #db #nextrow()
      pages$(i) = #row name$()
    next i
  end if
  call disconnect

  ' Get page history
  call connect
  #db execute("select date, time from page_history where upper(name) = upper("; quote$(currentName$); ") order by date desc, time desc limit 10")
  if #db hasanswer()  then
    dim history$(9)
    dim historyDate(9)
    dim historyTime(9)
    for i = 1 to #db rowcount()
      #row = #db #nextrow()
      date = #row date()
      time = #row time()
      history$(i - 1) = formatDate$(date$(date)) + " " + formatTime$(time)
      historyDate(i - 1) = date
      historyTime(i - 1) = time
    next i
  end if
  call disconnect

  ' Get list of images
  call getFiles

  call adminHeading "Edit Page - "; currentName$
  html "<h1>Edit Page - "
  print currentName$
  html "</h1>"
  if preview = 1 then
    preview = 0
    if newSidebarContent$ <> "" then html "<div class=""row-fluid""><div class=""span8"">"
    html "<div class=""well"">"
    call renderPage newContent$
    if newSidebarContent$ <> "" then
       html "</div></div><div class=""span4""><div class=""well well-small"">"
       call renderPage newSidebarContent$
       html "</div></div>"
    end if
    html "</div>"
  else
    if newPage = 1 then
      currentContent$ = ""
      newContent$ = ""
      sidebarContent$ = ""
      newSidebarContent$ = ""
      newHideFlag = 0
      newPageLocked = 0
    else
      newContent$ = currentContent$
      newSidebarContent$ = sidebarContent$
      newHideFlag = hideFlag
      newPageLocked = pageLocked
    end if
  end if
  html "<div class=""btn-toolbar"">"
  html "<div class=""btn-group"">"
  html "<a class=""btn"" href=""#"" onclick=""mod_selection('\n===== ',' =====\n', 'Heading 1')"">H1</a>"
  html "<a class=""btn"" href=""#"" onclick=""mod_selection('\n==== ', ' ====\n', 'Heading 2')"">H2</a>"
  html "<a class=""btn"" href=""#"" onclick=""mod_selection('\n=== ', ' ===\n', 'Heading 3')"">H3</a>"
  html "<a class=""btn"" href=""#"" onclick=""mod_selection('\n== ', ' ==\n', 'Heading 4')"">H4</a>"
  html "</div>"
  html "<div class=""btn-group"">"
  html "<a class=""btn"" href=""#"" onclick=""mod_selection('**', '**', 'bold')""><b>B</b></a>"
  html "<a class=""btn"" href=""#"" onclick=""mod_selection('//', '//', 'italic')""><i>I</i></a>"
  html "<a class=""btn"" href=""#"" onclick=""mod_selection('__', '__', 'underline')""><u>U</u></a>"
  html "<a class=""btn dropdown-toggle"" data-toggle=""dropdown"" href=""#"">Highlite <span class=""caret""></span></a>"
  html "<ul class=""dropdown-menu"">"
  html "<li><a href=""#"" onclick=""mod_selection('<error>', '</error>', 'Error')""><span class=""text-error"">Error</span></a></li>"
  html "<li><a href=""#"" onclick=""mod_selection('<info>', '</info>', 'Information')""><span class=""text-info"">Information</span></a></li>"
  html "<li><a href=""#"" onclick=""mod_selection('<muted>', '</muted>', 'Muted')""><span class=""muted"">Muted</span></a></li>"
  html "<li><a href=""#"" onclick=""mod_selection('<success>', '</success>', 'Success')""><span class=""text-success"">Success</span></a></li>"
  html "<li><a href=""#"" onclick=""mod_selection('<warning>', '</warning>', 'Warning')""><span class=""text-warning"">Warning</span></a></li>"
  html "</ul>"
  html "</div>"
  html "<div class=""btn-group"">"
  html "<a class=""btn dropdown-toggle"" data-toggle=""dropdown"" href=""#"">Alert <span class=""caret""></span></a>"
  html "<ul class=""dropdown-menu"">"
  html "<li><a href=""#"" onclick=""mod_selection('\n<alert>\n', '\n</alert>\n', 'Alert message')"">Default</a></li>"
  html "<li><a href=""#"" onclick=""mod_selection('\n<alert-error>\n', '\n</alert>\n', 'Error message')""><span class=""label label-important"">Error</span></a></li>"
  html "<li><a href=""#"" onclick=""mod_selection('\n<alert-info>\n', '\n</alert>\n', 'Info message')""><span class=""label label-info"">Information</span></a></li>"
  html "<li><a href=""#"" onclick=""mod_selection('\n<alert-success>\n', '\n</alert>\n', 'Success message')""><span class=""label label-success"">Success</span></a></li>"
  html "<li><a href=""#"" onclick=""mod_selection('\n<alert-warning>\n', '\n</alert>\n', 'Warning message')""><span class=""label label-warning"">Warning</span></a></li>"
  html "</ul>"
  html "</div>"
  html "<div class=""btn-group"">"
  html "<a class=""btn dropdown-toggle"" data-toggle=""dropdown"" href=""#"">List <span class=""caret""></span></a>"
  html "<ul class=""dropdown-menu"">"
  html "<li><a href=""#"" onclick=""mod_selection('\n* ', '', 'Item')"">Bullet</a></li>"
  html "<li><a href=""#"" onclick=""mod_selection('\n# ', '', 'Item')"">Number</a></li>"
  html "</ul>"
  html "</div>"
  html "<div class=""btn-group"">"
  html "<a class=""btn dropdown-toggle"" data-toggle=""dropdown"" href=""#"">Table <span class=""caret""></span></a>"
  html "<ul class=""dropdown-menu"">"
  html "<li><a href=""#"" onclick=""mod_selection('\n^ ', '', 'Heading ')"">New Header Row</a></li>"
  html "<li><a href=""#"" onclick=""mod_selection('\n| ', '', 'Item')"">New Data Row</a></li>"
  html "<li class=""divider""></li>"
  html "<li><a href=""#"" onclick=""mod_selection('^ ', '', 'Heading')"">New Header Cell</a></li>"
  html "<li><a href=""#"" onclick=""mod_selection('| ', '', 'Item')"">New Data Cell</a></li>"
  html "</ul>"
  html "</div>"
  html "</div>"

  html "<div class=""form-inline well well-small"">"
  listbox #link, pages$(), 1
  html " "
  html "<a class=""btn btn-mini"" href=""#"" onclick=""add_link()"">Add Link</a> "
  listbox #image, fileNames$(), 1
  html " "
  html "<a class=""btn btn-mini"" href=""#"" onclick=""add_image()"">Add Image</a>"
  html "</div>"

  html "<div class=""row-fluid""><div class=""span8""><p class=""muted"">Page Contents</p>"
  textarea #content, newContent$, 80, 20
  html "</div><div class=""span4""><p class=""muted"">Sidebar</p>"
  textarea #sidebar, newSidebarContent$, 20, 20
  html "</div></div>"

  html "<p>"
  button #save, "Save Changes", [acceptEdit]
  #save cssclass("btn btn-success")
  html " "
  button #preview, "Preview", [previewEditPage]
  #preview cssclass("btn")
  html " "
  button #cancel, "Cancel", [cancelEdit]
  #cancel cssclass("btn")
  html "</p><p><i class=""icon-ok-circle""></i> <b>Page Options</b><br/><label class=""checkbox inline"">"
  checkbox #hide, "Don't show in page menu ", newHideFlag
  html "</label>"
  if isAdmin(#user id()) then
    html " <label class=""checkbox inline"">"
    checkbox #locked, "Lock page ", newPageLocked
    html "</label>"
  end if
  html "</p><p><i class=""icon-time""></i> <b>Previous edits</b><br/><div class=""form-inline"">"
  listbox #history, history$(), 1
  html " "
  button #restorePage, "Restore", [restorePage]
  #restorePage cssclass("btn")
  html "</div></p></div>"
  call adminFooter
  html "<script type=""text/javascript"" src=""/";AppName$;"/bootstrap/js/field-selection.js""></script>"
  html "<script type=""text/javascript"">$('div.span8 > textarea').addClass('input-xxlarge');</script>"
  html "<script type=""text/javascript"">$('textarea').focus(function() {$('textarea').removeClass('focused'); $(this).addClass('focused')})</script>"
  html "<script type=""text/javascript"">function mod_selection(sStartTag, sEndTag, sDefault) {var $e = $('textarea.focused'); var txt = $e.fieldSelection().text; if (txt == '') txt = sDefault; txt = sStartTag + txt + sEndTag; $e.fieldSelection(txt); $e.focus();}</script>"
  html "<script type=""text/javascript"">function add_link() {var s = document.getElementById('#link'); var i = s.selectedIndex; var options = s.options; mod_selection('[[' + options[i].text + '|', ']]', '');}</script>"
  html "<script type=""text/javascript"">function add_image() {var s = document.getElementById('#image'); var i = s.selectedIndex; var options = s.options; mod_selection('{{' + options[i].text + '|', '}}', '');}</script>"
  wait

[restorePage]
  date = 0
  time = 0
  for i = 0 to 9
    if history$(i) = #history selection$() then
      date = historyDate(i)
      time = historyTime(i)
      exit for
    end if
  next i

  if date <> 0 then
    call connect
    #db execute("select content, sidebar from page_history where upper(name) = upper("; quote$(currentName$); ") and date = "; date; " and time = "; time)
    if #db hasanswer() then
      #row = #db #nextrow()
      #content text(#row content$())
      #sidebar text(#row sidebar$())
    end if
    call disconnect
  end if

  wait
 
[acceptEdit]
  newContent$ = #content contents$()
  newSidebarContent$ = #sidebar contents$()
  newHideFlag = #hide value()
  if isAdmin(#user id()) then
    newPageLocked = #locked value()
  else
    newPageLocked = pageLocked
  end if
  if newPage then
    call connect
    #db execute("insert into pages (name, content, date, time, hide, user, locked, sidebar) values ("; quote$(currentName$); ","; quote$(newContent$); ","; date$("days"); ","; time$("seconds"); ","; newHideFlag; ","; #user id(); ","; newPageLocked; ","; quote$(newSidebarContent$); ")")
    call disconnect
    call generateSitemap
  else
    call backupCurrentPage
    query$ = "update pages set content="; quote$(newContent$); ",hide="; newHideFlag; ",user="; #user id(); ",date="; date$("days"); ",time="; time$("seconds"); ",locked="; newPageLocked; ",sidebar="; quote$(newSidebarContent$); " where upper(name) = upper("; quote$(currentName$); ")"
    call execute query$
  end if
  currentContent$ = newContent$
  sidebarContent$ = newSidebarContent$
  pageTimestamp$ = formatDate$(date$("mm/dd/yyyy")) + " " + formatTime$(time$("seconds"))
  pageUpdateBy$ = #user username$()
  hideFlag = newHideFlag
  pageLocked = newPageLocked
  pageDeleted = 0

  successMessage$ = "Page saved."

[cancelEdit]
  newPage = 0
  call loadCurrentPage
  call displayCurrentPage
  wait

[deletePage]
  call adminHeading "Delete page - "; currentName$
  html "<div class=""alert alert-block alert-error"">"
  html "<h4>Delete page - "
  print currentName$;
  html "</h4>"
  html "<p>Are you sure that you want to delete this page? This action can not be undone.</p>"
  html "<p>"
  button #delete, "Delete", [acceptDelete]
  #delete cssclass("btn btn-danger")
  html " "
  button #cancel, "Cancel", [cancelDelete]
  #cancel cssclass("btn")
  html "</div>"
  call adminFooter
  wait

[acceptDelete]
  call backupCurrentPage
  query$ = "delete from pages where upper(name) = upper("; quote$(currentName$); ")"
  call execute query$
  call generateSitemap
  successMessage$ = "Page named " + currentName$ + " has been deleted."
  pageTimestamp$ = ""
  pageUpdateBy$ = ""
  pageDeleted = 1

[cancelDelete]
  call loadCurrentPage
  call displayCurrentPage
  wait

[register]
  call adminHeading "New User Registration"

  call displayMessages

  html "<div class=""alert alert-info"">Fill out the following form to register. Your wiki password will be emailed to the address given.</div>"

  html "<div class=""form-horizontal"">"
  html "<fieldset>"
  html "<legend>New User Registration</legend>"
  html "<div class=""control-group"">"
  html "<label class=""control-label required"">Username</label>"
  html "<div class=""controls"">"
  textbox #username, ""
  html "</div></div>"
  html "<div class=""control-group"">"
  html "<label class=""control-label required"">Email Address</label>"
  html "<div class=""controls"">"
  textbox #email, ""
  html "</div></div>"
  html "<div class=""form-actions"">"
  button #save, "Save", [acceptRegister]
  #save cssclass("btn btn-success")
  html " "
  button #cancel, "Cancel", [cancel]
  #cancel cssclass("btn")
  html "</div></fieldset></div>"
  call adminFooter
  wait

[acceptRegister]
  if #user register(#username contents$(), #email contents$()) = 0 then
    errorMessage$ = #user errorMessage$()
    goto [register]
  end if

  #user logout()

  call adminHeading "Registration Successful"
  html "<div class=""alert alert-block alert-success"">"
  html "<h4>Registration Successful</h4>"
  html "<p>An email has been sent to "; #email contents$(); " containing your wiki password.</p><p>"
  link #continue, "Return to the wiki", [cancel]
  #continue cssclass("btn")
  html "</p></div>"
  call adminFooter
  wait

' ======================
' ==== FILE MANAGER ====
' ======================

[fileManager]

  call getFiles

  call adminHeading "File Manager"
  call displayMessages
  html "<h1>File Manager</h1>"
  html "<p>"
  link #return, "Return to the wiki", [cancel]
  html " | "
  html "<a href=""#upload"">Skip to the Upload Form</a>"
  html "</p>"

  html "<table class=""table table-bordered table-striped"">"
  html "<thead><tr><th>Filename</th><th>Size</th><th>Date</th><th>Preview</th><th>Action</th></tr></thead>"
  html "<tbody>"
  for i = 0 to filecount - 1
    html "<tr><td>"
    html "<a href=""/" + Site$ + "/" + urlEncode$(fileNames$(i)) + """>"
    print fileNames$(i);
    html "</a>"
    html "</td><td>"
    print fileSizes(i);
    html "</td><td>"
    print fileTimes$(i);
    html "</td><td>"
    select case lower$(right$(fileNames$(i), 4))
      case ".gif", ".jpg", ".png"
        url$ = makeThumbnail$(fileNames$(i), "100x100")
        html "<img src=""" + url$ + """>"
    end select
    html "</td><td>"
    d$ = "delete" + str$(i)
    button #d$, "Delete File", [deleteFile]
    #d$ cssclass("btn btn-small btn-danger")
    #d$ setkey(fileNames$(i))
    html "</td></tr>"
  next i
  html "</tbody></table>"
  html "<div class=""well"">"
  html "<a name=""#upload""></a>"
  upload "Select file to upload: "; uploadedFile$
  
  if uploadedFile$ = "" then goto [fileManager]

  open uploadedFile$ for binary as #bfile
  filedata$ = input$(#bfile, LOF(#bfile))
  close #bfile
 
  'strip path if present (thanks IE!)
  imageFileName$ = basename$(uploadedFile$, "/")  ' Unix style path
  imageFileName$ = basename$(imageFileName$, "\") ' Windows/DOS style path

  'open new file with same name in uploads folder
  newfile$ = uploadDir$ + pathSeparator$ + imageFileName$
  if fileExists(newfile$) then
    call adminHeading "Replace existing file - "; imageFileName$
    html "<div class=""alert alert-block alert-danger"">"
    html "<h4>Replace existing file - "
    print imageFileName$
    html "</h4>"
    html "<p>Are you sure that you want to replace the existing file? This action can not be undone.</p><p>"
    button #replace, "Replace", [replaceFile]
    #replace cssclass("btn btn-danger")
    html " "
    button #cancelDelete, "Cancel", [fileManager]
    #cancelDelete cssclass("btn")
    html "</p></div>"
    call adminFooter
    wait
  end if

[replaceFile]
  open uploadDir$ + pathSeparator$ + imageFileName$ for binary as #bfile

  'write data to new file
  print #bfile, filedata$;
  close #bfile
 
  'delete uploaded file from root directory
  kill uploadedFile$

  successMessage$ = "File uploaded successfully."

  goto [fileManager]

[deleteFile]
  file$ = EventKey$

  call adminHeading "Delete file - "; file$
  html "<div class=""alert alert-block alert-danger"">"
  html "<h4>Delete file - "
  print file$;
  html "</h4>"
  html "<p>Are you sure that you want to delete this file? This action can not be undone.</p><p>"
  button #delete, "Delete", [acceptFileDelete]
  #delete cssclass("btn btn-danger")
  html " "
  button #cancelDelete, "Cancel", [cancelFileDelete]
  #cancelDelete cssclass("btn")
  html "<p></div>"
  call adminFooter
  wait

[acceptFileDelete]
  kill uploadDir$ + pathSeparator$ + file$

  successMessage$ = "File deleted successfully."

[cancelFileDelete]
  goto [fileManager]

' =======================
' ==== SITE SETTINGS ====
' =======================

[site]
  ' Get list of themes
  files #f, themeDir$ + pathSeparator$ + "*.min.css"
  if #f hasanswer() then
    dim themes$(#f rowcount())
    themes$(0) = "bootstrap"
    j = 1
    for i = 1 to #f rowcount()
      #f nextfile$()
      name$ = #f name$()
      name$ = mid$(name$, 1, len(name$) - 8)
      if name$ <> "bootstrap" and name$ <> "bootstrap-lightbox" then
        k = j
        while k > 1 and themes$(k - 1) > name$
          themes$(k) = themes$(k - 1)
          k = k - 1
        wend
        themes$(k) = name$
        j = j + 1
      end if
    next i
  end if
  
  call adminHeading "Site Settings"
  if errorMessage$ <> "" then
    html "<div class=""alert alert-block alert-error"">"
    html "<a class=""close"" data-dismiss=""alert"" href=""#"">&times;</a>"
    html errorMessage$
    html "</div>"
    errorMessage$ = ""
  end if
  html "<fieldset><legend>Site Details</legend>"
  html "<label class=""required"">Site Name</label>"
  textbox #siteName, siteName$, 40
  html "<label>Site Description</label>"
  textbox #siteDesc, siteDesc$, 80
  html "<label>Site URL</label>"
  textbox #siteUrl, siteUrl$, 80
  html "</fieldset>"
  html "<fieldset><legend>Site Options</legend>"
  html "<label class=""required"">Theme</label>"
  listbox #theme, themes$(), 1
  #theme select(siteTheme$)
  html "<label class=""required"">Date Format</label>"
  if dateFormat$ = "" then dateFormat$ = "mm/dd/yyyy"
  textbox #dateFormat, dateFormat$, 20
  html "<span class=""help-inline"">(eg. mm/dd/yyyy, dd/mm/yyyy, yyyy-mm-dd, etc)</span>"
  html "<label class=""checkbox"">"
  checkbox #allowRegistration, "Allow Registration ", allowRegistration
  html "</label><label class=""checkbox"">"
  checkbox #allowUploads, "Allow Uploads", allowUploads
  html "</label><label class=""checkbox"">"
  checkbox #allowObjects, "Allow Objects", allowObjects
  html "</label><label class=""checkbox"">"
  checkbox #allowPlugins, "Allow Plugins", allowPlugins
  html "</label><label class=""checkbox"">"
  checkbox #showBreadcrumbs, "Show Breadcrumbs", showBreadcrumbs
  html "</label><label class=""checkbox"">"
  checkbox #newWindow, "Open External Links in a New Window", newWindow
  html "</label></fieldset>"
  html "<fieldset><legend>Mail Configuration</legend>"
  html "<label>SMTP Host</label>"
  textbox #smtpHost, smtpHost$, 40
  html "<label>SMTP Password (if required)</label>"
  passwordbox #smtpPassword, smtpPassword$, 40
  html "<label>From Address</label>"
  textbox #fromAddress, fromAddress$, 40
  html "</fieldset>"
  html "<div class=""form-actions"">"
  button #save, "Save", [acceptSite]
  #save cssclass("btn btn-success")
  html " "
  button #cancel, "Cancel", [cancelSite]
  #cancel cssclass("btn")
  html "</div>"
  call adminFooter
  wait

[acceptSite]
  siteName$ = #siteName contents$()
  siteDesc$ = #siteDesc contents$()
  siteUrl$ = #siteUrl contents$()
  if siteUrl$ <> "" then
    if left$(siteUrl$, 7) <> "http://" and left$(siteUrl$, 8) <> "https://" then siteUrl$ = "http://" + siteUrl$
    if right$(siteUrl$, 1) <> "/" then siteUrl$ = siteUrl$ + "/"
  end if
  dateFormat$ = #dateFormat contents$()
  allowRegistration = #allowRegistration value()
  allowUploads = #allowUploads value()
  allowObjects = #allowObjects value()
  allowPlugins = #allowPlugins value()
  showBreadcrumbs = #showBreadcrumbs value()
  newWindow = #newWindow value()
  smtpHost$ = #smtpHost contents$()
  smtpPassword$ = #smtpPassword contents$()
  fromAddress$ = #fromAddress contents$()
  siteTheme$ = #theme selection$()
  
  errorMessage$ = ""

  if siteName$ = "" then errorMessage$ = appendMessage$(errorMessage$, "The Site Name must be supplied.")
  if dateFormat$ = "" then errorMessage$ = appendMessage$(errorMessage$, "The Date Format must be supplied.")

  if errorMessage$ <> "" then goto [site]
  
  call execute "delete from site"
  call execute "insert into site (name, description, url, dateformat, registration, objects, plugins, breadcrumbs, smtphost, smtppassword, fromaddress, theme, new_window, userdb, uploads) values ("; quote$(siteName$); ","; quote$(siteDesc$); ","; quote$(siteUrl$); ","; quote$(dateFormat$); ","; allowRegistration; ","; allowObjects; ","; allowPlugins; ","; showBreadcrumbs; ","; quote$(smtpHost$); ","; quote$(smtpPassword$); ","; quote$(fromAddress$); ","; quote$(siteTheme$); ","; newWindow; ","; quote$(userDB$); ","; allowUploads; ")"

  call loadSite

  successMessage$ = "Site settings saved."
  call displayCurrentPage
  wait

[cancelSite]
  call loadSite
  call displayCurrentPage
  wait

' =========================
' ==== USER MANAGEMENT ====
' =========================

[users]
  userAdmin = 1
  call adminHeading "User Management"
  call displayMessages
  html "<h1>User Management</h1>"
  html "<p>"
  link #returnToWiki, "Return to the wiki", [cancel]
  html "</p>"
  if #userList listUsers("USERNAME") = 0 then
    call displayError #userList errorMessage$()
  else
    html "<table class=""table table-bordered table-striped"">"
    html "<thead><tr><th>Username</ht><th>Email</th><th>Description</th><th>Admin?</th><th>Locked?</th><th>Last Login</th><th>Action</th></tr></thead>"
    html "<tbody>"
    while #userList nextUser()
      html "<tr><td>"
      print #userList username$();
      html "</td><td><a href=""mailto:"
      print #userList email$();
      html """>"
      print #userList email$();
      html "</a>"
      html "</td><td>"
      print #userList description$();
      html "</td><td>"
      if isAdmin(#userList id()) then
        print "Yes";
      else
        print "No";
      end if
      html "</td><td>"
      if #userList locked() then
        print "Yes";
      else
        print "No";
      end if
      html "</td><td>"
      print formatDate$(date$(#userList lastLoginDate()));
      html "</td><td>"
      button #editUser, "Edit", [editUser]
      #editUser setkey(str$(#userList id()))
      #editUser cssclass("btn")
      if #user id() <> #userList id() then
        html " "
        button #deleteUser, "Delete", [deleteUser]
        #deleteUser setkey(str$(#userList id()))
        #deleteUser cssclass("btn btn-danger")
      end if
      html "</td></tr>"
    wend
    html "</tbody></table>"
    html "<p>"
    button #newUser, "Add New User", [newUser]
    #newUser cssclass("btn btn-success")
    html "</p>"
  end if
  call adminFooter
  wait

[newUser]
  call adminHeading "New User"
  call displayMessages
  html "<div class=""form-horizontal"">"
  html "<fieldset>"
  html "<legend>New User</legend>"
  html "<div class=""control-group"">"
  html "<label class=""control-label required"">Username</label>"
  html "<div class=""controls"">"
  textbox #username, ""
  html "</div></div>"
  html "<div class=""control-group"">"
  html "<label class=""control-label required"">Email Address</label>"
  html "<div class=""controls"">"
  textbox #email, ""
  html "</div></div>"
  html "<div class=""control-group"">"
  html "<label class=""control-label"">Description</label>"
  html "<div class=""controls"">"
  textbox #desc, "", 80
  html "</div></div>"
  html "<div class=""control-group"">"
  html "<div class=""controls"">"
  html "<label class=""checkbox"">"
  checkbox #locked, "Account Locked", 0
  html "</label>"
  html "<label class=""checkbox"">"
  checkbox #admin, "Wiki Administrator", 0
  html "</label>"
  html "</div></div>"
  html "<div class=""control-group"">"
  html "<label class=""control-label"">Password</label>"
  html "<div class=""controls"">"
  passwordbox #password, ""
  html "</div></div>"
  html "<div class=""form-actions"">"
  button #save, "Save", [acceptNewUser]
  #save cssclass("btn btn-success")
  html " "
  button #cancel, "Cancel", [users]
  #cancel cssclass("btn")
  html "</div></fieldset></div>"
  call adminFooter
  wait

[acceptNewUser]
  if #userList new(#username contents$(), #password contents$()) = 0 then
    errorMessage$ = #userList errorMessage$()
    goto [newUser]
  end if
  ' Note - after this point the user exists, so on error redirect to the edit user form
  if #userList setEmail(#email contents$()) = 0 then
    errorMessage$ = #userList errorMessage$()
    goto [editUser]
  end if
  if #userList setDescription(#desc contents$()) = 0 then
    errorMessage$ = #userList errorMessage$()
    goto [editUser]
  end if

  if #locked value() then
    if #userList lockUser() = 0 then
      errorMessage$ = #userList errorMessage$()
      goto [editUser]
    end if
  else
    if #userList unlockUser() = 0 then
      errorMessage$ = #userList errorMessage$()
      goto [editUser]
    end if
  end if

  if #admin value() then
    call execute "insert into admins(id) values (" + str$(#userList id()) + ")"
  end if

  goto [users]

[editUser]
  if left$(EventKey$, 1) <> "#" then
    #userList selectUserById(val(EventKey$))
  end if

  if userAdmin then
    call adminHeading "Edit User"
  else
    call adminHeading "Edit Profile"
  end if

  call displayMessages

  html "<div class=""form-horizontal"">"
  html "<fieldset>"
  if userAdmin then
    html "<legend>Edit User</legend>"
  else
    html "<legend>Edit Profile</legend>"
  end if
  html "<div class=""control-group"">"
  html "<label class=""control-label required"">Username</label>"
  html "<div class=""controls"">"
  textbox #username, #userList username$()
  html "</div></div>"
  html "<div class=""control-group"">"
  html "<label class=""control-label required"">Email Address</label>"
  html "<div class=""controls"">"
  textbox #email, #userList email$()
  html "</div></div>"
  html "<div class=""control-group"">"
  html "<label class=""control-label"">Description</label>"
  html "<div class=""controls"">"
  textbox #desc, #userList description$(), 80
  html "</div></div>"
  if #user id() <> #userList id() and isAdmin(#user id()) then
    html "<div class=""control-group"">"
    html "<div class=""controls"">"
    html "<label class=""checkbox"">"
    checkbox #locked, "Account Locked", #userList locked()
    html "</label>"
    html "<label class=""checkbox"">"
    checkbox #admin, "Wiki Administrator", isAdmin(#userList id())
    html "</label>"
    html "</div></div>"
  end if
  if #user id() = #userList id() then
    html "<div class=""control-group"">"
    html "<label class=""control-label"">Old Password</label>"
    html "<div class=""controls"">"
    passwordbox #oldPassword, ""
    html "</div></div>"
    html "<div class=""control-group"">"
    html "<label class=""control-label"">New Password</label>"
    html "<div class=""controls"">"
    passwordbox #newPassword, ""
    html "</div></div>"
    html "<div class=""control-group"">"
    html "<label class=""control-label"">Repeat New Password</label>"
    html "<div class=""controls"">"
    passwordbox #verifyPassword, ""
    html "</div></div>"
  end if
  html "<div class=""form-actions"">"
  button #save, "Save", [acceptUserEdit]
  #save cssclass("btn btn-success")
  html " "
  if userAdmin then
    button #cancel, "Cancel", [users]
  else
    button #cancel, "Cancel", [cancel]
  end if
  #cancel cssclass("btn")
  html "</div></fieldset></div>"
  call adminFooter
  wait

[acceptUserEdit]
  if #userList setUsername(#username contents$()) = 0 then
    errorMessage$ = #userList errorMessage$()
    goto [editUser]
  end if
  if #userList setEmail(#email contents$()) = 0 then
    errorMessage$ = #userList errorMessage$()
    goto [editUser]
  end if
  if #userList setDescription(#desc contents$()) = 0 then
    errorMessage$ = #userList errorMessage$()
    goto [editUser]
  end if

  if #user id() <> #userList id() and isAdmin(#user id()) then
    if #locked value() then
      if #userList lockUser() = 0 then
        errorMessage$ = #userList errorMessage$()
        goto [editUser]
      end if
    else
      if #userList unlockUser() = 0 then
        errorMessage$ = #userList errorMessage$()
        goto [editUser]
      end if
    end if

    if #admin value() then
      call execute "insert into admins(id) values (" + str$(#userList id()) + ")"
    else
      call execute "delete from admins where id = " + str$(#userList id())
    end if
  end if

  if #user id() = #userList id() and (#oldPassword contents$() <> "" or #newPassword contents$() <> "" or #verifyPassword contents$() <> "") then
    if #user changePassword(#oldPassword contents$(), #newPassword contents$(), #verifyPassword contents$()) = 0 then
      errorMessage$ = #user errorMessage$()
      goto [editUser]
    end if
  end if

  if #user id() = #userList id() then #user selectUserById(#userList id()) 'Reload user details

  if userAdmin then
    goto [users]
  else
    goto [cancel]
  end if

[deleteUser]
  #userList selectUserById(val(EventKey$))

  call adminHeading "Delete User - "; #userList username$()
  html "<div class=""alert alert-block alert-error"">"
  html "<h4>Delete User - "
  print #userList username$();
  html "</h4>"
  html "<p>Are you sure that you want to delete this user? This action can not be undone.</p><p>"
  button #delete, "Delete", [acceptDeleteUser]
  #delete cssclass("btn btn-danger")
  html " "
  button #cancelDelete, "Cancel", [users]
  #cancelDelete cssclass("btn")
  html "</p></div>"
  call adminFooter
  wait

[acceptDeleteUser]
  #userList deleteUser()
  goto [users]

' =============================
' ==== USER DATABASE SETUP ====
' =============================

[setupUserDB]
  if newSites = 1 then
    ' For security reasons, don't allow user database selection when on the fly site creation is allowed
    userDB$ = Site$
    goto [setupAdmin]
  end if

  call adminHeading "Setup Users Database"
  call displayMessages
  html "<p>Welcome to your new wiki. First you must decide where to store user details. "
  html "These can be kept in the wiki database (the default) or in another database.</p>"
  html "<label class=""required"">User Database</label>"
  textbox #userdb, Site$ + ".db"
  html "<div class=""form-actions"">"
  button #continue, "Continue", [acceptUserDB]
  #continue cssclass("btn btn-success")
  html "</div>"
  call adminFooter
  wait

[acceptUserDB]
  userDB$ = #userdb contents$()
  if instr(userDB$, pathSeparator$) > 0 then
    errorMessage$ = "User Database must not contain '" + pathSeparator$ + "'."
    goto [setupUserDB]
  end if

  if userDB$ <> "" then
    userdbFilename$ = DefaultDir$ + pathSeparator$ + userDB$
    #user setDatabaseName(userdbFilename$)
    #userList setDatabaseName(userdbFilename$)
  end if

' =============================
' ==== ADMIN ACCOUNT SETUP ====
' =============================

[setupAdmin]
  call adminHeading "Setup Administrator Account"
  call displayMessages
  html "<p>Now you must create an administrator account. "
  html "Only administrators can change site settings and edit other users details.</p>"
  html "<label class=""required"">Username</label>"
  textbox #username, "admin"
  html "<label class=""required"">Email Address</label>"
  textbox #email, ""
  html "<label>Password</label>"
  passwordbox #password, ""
  html "<div class=""form-actions"">"
  button #continue, "Continue", [acceptSetupAdmin]
  #continue cssclass("btn btn-success")
  html "</div>"
  call adminFooter
  wait

[acceptSetupAdmin]
  ' Check for existing user (in case we are using a shared users database)
  if #user login(#username contents$(), #password contents$()) = 0 then
    if #user new(#username contents$(), #password contents$()) = 0 then
      errorMessage$ = #user errorMessage$()
      goto [setupAdmin]
    end if

    if #user setDescription("Administrator") = 0 then
      errorMessage$ = #user errorMessage$()
      goto [setupAdmin]
    end if
  end if

  if #user setEmail(#email contents$()) = 0 then
    errorMessage$ = #user errorMessage$()
    goto [setupAdmin]
  end if

  call execute "insert into admins(id) values (" + str$(#user id()) + ")"
  currentName$ = "Home"
  call loadCurrentPage

  successMessage$ = "The administrator account has been successfully created."
  goto [site]

' =========================
' ==== CREATE NEW SITE ====
' =========================

[newSite]
  call adminHeading "Create New Site"
  html "<p>Please enter an identifier for the new site - this will also be used as the "
  html "database name for the new site so it must be a valid filename.</p>"
  if errorMessage$ <> "" then
    call displayError errorMessage$
    errorMessage$ = ""
  end if

  html "<label class=""required"">Site Identifier</label>"
  textbox #siteId, ""
  html "<div class=""form-actions"">"
  button #create, "Create Site", [acceptNewSite]
  #create cssclass("btn btn-success")
  html " "
  button #cancel, "Cancel", [cancelNewSite]
  #cancel cssclass("btn")
  html "</div>"
  call adminFooter
  wait

[acceptNewSite]
  if #siteId contents$() = "" then
    errorMessage$ = "You must enter a site identifier."
    goto [newSite]
  end if

  if instr(#siteId contents$(), pathSeparator$) > 0 then
    errorMessage$ = "The site identifier must not contain '" + pathSeparator + "'."
    goto [newSite]
  end if

  newSite$ = lower$(#siteId contents$())

  newDatabaseFilename$ = DatabaseDir$ + pathSeparator$ + newSite$ + ".db"

  if fileExists(newDatabaseFilename$) then
    errorMessage$ = "A database file with this name already exists. Please choose another site identifier."
    goto [newSite]
  end if

  Site$ = newSite$
  DatabaseFilename$ = newDatabaseFilename$
  uploadDir$ = ResourcesRoot$ + pathSeparator$ + Site$

  call createDirectories
  call createDatabase

  call adminHeading "New Site Created"
  html "<div class=""alert alert-block alert-success"">"
  html "<p>The new site has been successfully created. You must now setup the site.</p><p>"
  button #continue, "Setup New Site", [bootSite]
  #continue cssclass("btn btn-success")
  html "</p></div>"
  call adminFooter
  wait

[cancelNewSite]
  call displayCurrentPage
  wait

[handleError]
  cls
  head "<link href=""/"; AppName$; "/bootstrap/css/bootstrap.min.css"" rel=""stylesheet""/>"
  html "</div><div class=""container-fluid""><br />"
  html "<div class=""alert alert-block alert-error"">"
  html "<h2>Unexpected Error</h2>"
  html "<p>An unexpected error has occured.</p>"
  html "<p>Error: ("; Err; ") "
  print Err$;
  html "</p></div></div><div>"
  call disconnect
  end

' =====================
' ==== SUBROUTINES ====
' =====================

'
' Add the page (name$) to the breadcrumb
'
sub addBreadcrumb name$
  for i = 0 to 10
    if breadcrumbs$(i) = "" then exit for
    if truncate then breadcrumbs$(i) = ""
    if breadcrumbs$(i) = name$ then truncate = 1
  next i
  if i = 10 then
    for i = 1 to 9
      breadcrumbs$(i) = breadcrumbs$(i + 1)
    next i
  end if
  if not(truncate) then breadcrumbs$(i) = name$
end sub

'
' Display footer for Administration pages
'
sub adminFooter
  html "<hr/>"
  call attribution
  html "</div>"
  html "<script type=""text/javascript"" src=""/";AppName$;"/bootstrap/js/jquery.min.js""></script>"
  html "<script type=""text/javascript"" src=""/";AppName$;"/bootstrap/js/bootstrap.min.js""></script>"
  if lightboxScript then
    head "<link href=""/";AppName$;"/bootstrap/css/bootstrap-lightbox.min.css"" rel=""stylesheet"" />"
    html "<script type=""text/javascript"" src=""/";AppName$;"/bootstrap/js/bootstrap-lightbox.min.js""></script>"
    lightboxScript = 0
  end if
  html "<div>"
end sub

'
' Display heading for Administration pages
'
sub adminHeading heading$
  cls

  titlebar siteName$; " - "; heading$

  head "<link href=""/"; AppName$; "/bootstrap/css/bootstrap.min.css"" rel=""stylesheet""/>"
  head "<style type=""text/css"">body {padding-top: 60px}</style>"
  head "<style type=""text/css"">label.required:after {content:"" *""; color:red;}</style>"

  html "</div>"
  html "<div class=""navbar navbar-fixed-top navbar-inverse"">"
  html "<div class=""navbar-inner"">"
  html "<div class=""container-fluid"">"
  html "<a class=""brand"" href=""#"">"
  print siteName$;
  html "</a>"
  html "<ul class=""nav pull-right"">"
  html "<li>"
  link #cancel, "Return to Wiki", [cancel]
  html "</li>"
  html "</ul>"
  html "</div></div></div><br/>"
  html "<div class=""container-fluid"">"
end sub

'
' Display attribution links
' 
sub attribution
  html "<p class=""pull-right"">Powered by RunWikiNG and <a href=""http://www.runbasic.com/"">Run BASIC</a>.<br />"
  html "Built with <a href=""http://twitter.github.io/bootstrap/"">Bootstrap</a>. Icons from <a href=""http://glyphicons.com/"">Glyphicons</a>.</p>"
end sub

'
' Backup the current page
'
sub backupCurrentPage
  call execute "insert into page_history select * from pages where name = "; quote$(currentName$)
end sub

'
' Connect to the database
'
sub connect
  sqliteconnect #db, DatabaseFilename$
end sub

'
' Create and initailise the database if required
'
sub createDatabase
  call connect
  ' Create tables if required
  #db execute("select * from sqlite_master where name = 'site' and type = 'table'")
  if not(#db hasanswer()) then
    ' New database, create all the required tables

    ' Site table
    #db execute("create table site (name text, description text, url text, dateformat text, registration int, objects int, plugins int, breadcrumbs int, smtphost text, smtppassword text, fromaddress text, theme text, new_window int, userdb text, uploads int)")

    ' Pages table
    #db execute("create table pages (name text, content text, date int, time int, hide int, user int, locked int, sidebar text)")

    ' Insert default home page
    content$ = "This is your initial home page for your wiki.  Please edit this and make it your own."
    #db execute("insert into pages (name, content, date, time, user) values ('Home',"; quote$(content$); ","; date$("days"); ","; time$("seconds"); ", 0)")

    ' Page history table
    #db execute("create table page_history (name text, content text, date int, time int, hide int, user int, locked int, sidebar text)")

    ' Admins table
    #db execute("create table admins (id int)")

    ' DB version table
    #db execute("create table db_version (version integer)")
    #db execute("insert or replace into db_version(version) values (2)")
  else
    ' Existing database

    ' If the db_version tables does not exists, its a version 1 database
    #db execute("select * from sqlite_master where name = 'db_version' and type='table'")
    if not(#db hasanswer()) then
      dbVersion = 1
    else
      #db execute("select version from db_version")
      if not(#db hasanswer()) then
        dbVersion = 2 ' Fix for badly initialized version 2 databases
      else
        #row = #db #nextrow()
        dbVersion = max(#row version(), 2) ' Fix for badly initialized version 2 databases
      end if
    end if

    if dbVersion = 1 then
      ' Upgrade from version 1 database
      #db execute("create table db_version(version integer)")
      #db execute("alter table pages add sidebar text")
      #db execute("alter table page_history add sidebar text")
    end if

    if dbVersion <> 2 then #db execute("insert or replace into db_version(version) values ("; dbVersion; ")")
  end if
  call disconnect
end sub

'
' Create directories if required
'
sub createDirectories
  if not(dirExists(DatabaseDir$)) then result = mkdir(DatabaseDir$)

  if not(dirExists(uploadDir$)) then result = mkdir(uploadDir$)

  thumbnailsDir$ = uploadDir$ + pathSeparator$ + "thumbnails"
  if not(dirExists(thumbnailsDir$)) then result = mkdir(thumbnailsDir$)
end sub

'
' Create stacks used by the renderPage subroutine
'
sub createStacks
  run "stackObject", #blockStack
  run "stackObject", #tagStack
  run "stackObject", #htmlStack
end sub

'
' Disconnect from the database
'
sub disconnect
  #db disconnect()
end sub

'
' Display the breadcrumbs
'
sub displayBreadcrumb
  if showBreadcrumbs then
    html "<ul class=""breadcrumb"">"
    for i = 0 to 9
      if breadcrumbs$(i) = "" then exit for
      if i = 9 or breadcrumbs$(i + 1) = "" then
        html "<li class=""active"">"
        print breadcrumbs$(i);
        html "</li>"
      else
        html "<li>"
        link #link, breadcrumbs$(i), loadPage
        #link setid("breadcrumb";i)
        #link setkey(breadcrumbs$(i))
        html " <span class=""divider"">/</span></li>"
      end if
    next i
    html "</ul>"
  end if
end sub

'
' Display an error message
'
sub displayError message$
  html "<div class=""alert alert-error"">"
  html "<a class=""close"" data-dismiss=""alert"" href=""#"">&times;</a>"
  print message$;
  html "</div>"
end sub

'
' Display the current page
'
sub displayCurrentPage
  cls
  titlebar siteName$; " - "; currentName$
  head "<link href="""; cssFile$; """ rel=""stylesheet""/>"
  head "<style type=""text/css"">body {padding-top: 60px}</style>"
  html "</div>"
  html "<div class=""navbar navbar-fixed-top navbar-inverse"">"
  html "<div class=""navbar-inner"">"
  html "<div class=""container-fluid"">"
  html "<a class=""brand"" href=""#"">"
  print siteName$;
  html "</a>"
  html "<ul class=""nav"">"
  call pageList
  html "</ul>"

  html "<ul class=""nav pull-right"">"
  if #user id() = 0 then
    html "<li>"
    if allowRegistration then
      link #login, "Login/Register", [login]
    else
      link #login, "Login", [login]
    end if
    html "</li>"
  else
    html "<li class=""dropdown"">"
    html "<a href=""#"" class=""navbar-link dropdown-toggle"" data-toggle=""dropdown"">Options <b class=""caret""></b></a>"
    html "<ul class=""dropdown-menu"">"
    html "<li>"
    link #profile, "Profile", [editUser]
    #profile setkey(str$(#user id()))
    html "</li>"
    html "<li class=""divider""></li>"
    html "<li>"
    link #gotoPage, "Go to page", [gotoPage]
    html "</li>"
    if not(specialPage(currentName$)) then
      html "<li class=""divider""></li>"
      if (not(pageLocked) or isAdmin(#user id())) then
        if pageDeleted then
          html "<li>"
          link #createPage, "Create page", [createPage]
          #createPage setkey(currentName$)
          html "</li>"
        else
          html "<li>"
          link #editPage, "Edit page", [editPage]
          html "</li>"
          html "<li>"
          link #renamePage, "Rename page", [renamePage]
          html "</li>"
          html "<li>"
          link #deletePage, "Delete page", [deletePage]
          html "</li>"
        end if
      else
        html "<li class=""disabled""><a href=""#"">Page locked</a></li>"
      end if
      if isAdmin(#user id()) or allowUploads then
        html "<li>"
        link #fileManager, "Manage files", [fileManager]
        html "</li>"
      end if
    end if
    if isAdmin(#user id()) then
      html "<li class=""divider""></li>"
      html "<li>"
      link #site, "Site settings", [site]
      html "</li>"
      if adminNewSites = 1 then
        html "<li>"
        link #newSite, "New site", [newSite]
        html "</li>"
      end if
      html "<li>"
      link #users, "Manage users", [users]
      html "</li>"
      html "<li>"
      link #restore, "Recover page", [recoverPage]
      html "</li>"
    end if
    html "<li class=""divider""></li>"
    html "<li>"
    link #logout, "Logout", [logout]
    html "</li>"
    html "</ul>"
    html "</li>"
  end if
  html "</ul>"
  html "</div></div></div><br/>"
  html "<div class=""container-fluid"">"
  call displayMessages
  call displayBreadcrumb
  html "<div class=""row-fluid"">"
  html "<div class=""span8"">"
  html "<h1>"
  print currentName$;
  html "</h1>"
  if specialPage(currentName$) then
    select case currentName$
      case "Page Index"
        call pageIndex
      case "Recent Changes"
        call recentChanges
      case "Search Results"
        call pageSearch searchText$
    end select
  else
    call renderPage currentContent$
    if #user id() <> 0 and pageDeleted then
      html "<p>"
      link #createThisPage, "Create this page", [createPage]
      #createThisPage setkey(currentName$)
      #createThisPage cssclass("btn btn-success")
      html "</p>"
    end if
  end if
  html "</div>"
  html "<div class=""span4"">"
  html "<div class=""form-search"">"
  html "<div class=""input-append"">"
  textbox #searchText, searchText$
  button #search, "Search", [startSearch]
  #search cssclass("btn")
  html "</div></div><br/>"
  html "<div class=""well well-small"">"
  html "<ul class=""nav nav-list"">"
  html "<li class=""nav-header"">Special Pages</li>"
  if currentName$ = "Page Index" then
    html "<li class=""active"">"
  else
    html "<li>"
  end if
  link #index, "Page Index", [index]
  html "</li>"
  if currentName$ = "Recent Changes" then
    html "<li class=""active"">"
  else
    html "<li>"
  end if
  link #recent, "Recent Changes", [recent]
  html "</li></ul></div>"
  if sidebarContent$ <> "" then
    html "<div class=""well well-small"">"
    call renderPage sidebarContent$
    html "</div>"
  end if
  html "</div></div>"
  html "<hr/>"
  call attribution
  html "<p><a href=""#"">Back to top</a></p>"
  html "</div>"
  html "<script type=""text/javascript"" src=""/";AppName$;"/bootstrap/js/jquery.min.js""></script>"
  html "<script type=""text/javascript"" src=""/";AppName$;"/bootstrap/js/bootstrap.min.js""></script>"
  html "<script type=""text/javascript"">$('div.form-search input').addClass('search-query');</script>"
  if lightboxScript then
    head "<link href=""/";AppName$;"/bootstrap/css/bootstrap-lightbox.min.css"" rel=""stylesheet"" />"
    html "<script type=""text/javascript"" src=""/";AppName$;"/bootstrap/js/bootstrap-lightbox.min.js""></script>"
    lightboxScript = 0
  end if
  html "<div>"
end sub

'
' Display any error or success messages
'
sub displayMessages
  if errorMessage$ <> "" then
    html "<div class=""alert alert-error"">"
    html "<a class=""close"" data-dismiss=""alert"" href=""#"">&times;</a>"
    print errorMessage$;
    html "</div>"
    errorMessage$ = ""
  else
    if successMessage$ <> "" then
      html "<div class=""alert alert-success"">"
      html "<a class=""close"" data-dismiss=""alert"" href=""#"">&times;</a>"
      print successMessage$;
      html "</div>"
    end if
    successMessage$ = ""
  end if
end sub

'
' Execute the SQL statement (sql$)
'
sub execute sql$
  call connect
  #db execute(sql$)
  call disconnect
end sub

'
' Generate the sitemap file
'
sub generateSitemap
  if siteUrl$ <> "" then
    ' Create the sitemap
    open ResourcesRoot$ + pathSeparator$ + "sitemap.txt" for output as #sitemap

    call connect
    #db execute("select name from pages order by name")
    while #db hasanswer()
      #row = #db #nextrow()
      name$ = #row name$()
      print #sitemap, baseUrl$; "&page="; urlEncode$(name$)
    wend
    call disconnect
    close #sitemap

    ' Create robots.txt
    open ResourcesRoot$ + pathSeparator$ + "robots.txt" for output as #robots
    print #robots, "Sitemap: "; siteUrl$ + "sitemap.txt"
    close #robots
  end if
end sub

'
' Generate a list of files in the upload directory
'
sub getFiles
  files #f, uploadDir$ + pathSeparator$ + "*"
  if #f hasanswer() then
    filecount = 0
    for i = 1 to #f rowcount()
      #f nextfile$()
      if not(#f isdir()) and lower$(file$) <> "thumbs.db" then
        fileNames$(filecount) = #f name$()
        fileSizes(filecount) = #f size()
        fileTimes$(filecount) = #f date$(); " "; #f time$()
        filecount = filecount + 1
      end if
    next i
  end if

  ' Sort file names
  for i = 1 to filecount - 1
    name$ = fileNames$(i)
    size = fileSizes(i)
    time$ = fileTimes$(i)
    j = i - 1
    while j >= 0
      if fileNames$(j) <= name$ then exit while
      fileNames$(j + 1) = fileNames$(j)
      fileSizes(j + 1) = fileSizes(j)
      fileTimes$(j + 1) = fileTimes$(j)
      j = j - 1
    wend
    fileNames$(j + 1) = name$
    fileSizes(j + 1) = size
    fileTimes$(j + 1) = time$
  next i
end sub

'
' Load the current page from the database
'
sub loadCurrentPage
  call connect
  #db execute("select name, hide, content, user, date, time, locked, sidebar from pages where upper(name) = upper("; quote$(currentName$); ")")
  if #db hasAnswer() then
    #result = #db #nextRow()
    currentName$ = #result name$()
    hideFlag = #result hide()
    currentContent$ = #result content$()
    sidebarContent$ = #result sidebar$()
    user = #result user()
    date = #result date()
    time = #result time()
    pageLocked = #result locked()
    if #userList selectUserById(user) then
      pageUpdateBy$ = #userList username$()
      #userList logout()
    else
      pageUpdateBy$ = "anonymous"
    end if
    pageTimestamp$ = formatDate$(date$(date)) + " " + formatTime$(time)
    pageDeleted = 0
    preview = 0
  else
    currentContent$ = "<alert-error>=== Page Not Found === The page """; currentName$; """ does not exist.</alert>"
    sidebarContent$ = ""
    pageDeleted = 1
    pageLocked = 0
    pageTimestamp$ = ""
    pageUpdateBy$ = ""
  end if
  call disconnect
end sub

'
' Load and display the page (name$)
'
sub loadPage name$
  currentName$ = name$
  call loadCurrentPage
  call addBreadcrumb currentName$
  call displayCurrentPage
end sub

'
' Load all site parameters from the database
'
sub loadSite
  siteName$ = ""
  siteDesc$ = ""
  siteUrl$ = ""
  dateFormat$ = ""
  allowRegistration = 0
  allowUploads = 0
  allowObjects = 0
  allowPlugins = 0
  showBreadcrumbs = 0
  smtpHost$ = ""
  smtpPassword$ = ""
  fromAddress$ = ""
  siteTheme$ = ""
  newWindow = 0
  userDB$ = ""

  call connect
  #db execute("select name, description, url, dateformat, registration, objects, plugins, breadcrumbs, smtphost, smtppassword, fromaddress, theme, new_window newwindow, userdb, uploads from site")
  if #db hasanswer() then
    #result = #db #nextRow()
    siteName$ = #result name$()
    siteDesc$ = #result description$()
    siteUrl$ = #result url$()
    dateFormat$ = #result dateformat$()
    allowRegistration = #result registration()
    allowObjects = #result objects()
    allowPlugins = #result plugins()
    showBreadcrumbs = #result breadcrumbs()
    smtpHost$ = #result smtphost$()
    smtpPassword$ = #result smtpPassword$()
    fromAddress$ = #result fromAddress$()
    siteTheme$ = #result theme$()
    newWindow = #result newwindow()
    userDB$ = #result userdb$()
    allowUploads = #result uploads()
    
    if not(fileExists(themeDir$ + pathSeparator$ + siteTheme$ + ".min.css")) then siteTheme$ = "bootstrap"
    cssFile$ = "/" + AppName$ + "/bootstrap/css/" + siteTheme$ + ".min.css"

    if smtpHost$ <> "" then
      #user setSmtpProfile(smtpHost$, smtpPassword$, fromAddress$)
    end if
    if siteUrl$ <> "" then 
      baseUrl$ = siteUrl$ + "seaside/go/runbasicpersonal?app=" + AppName$ + "&amp;site=" + urlEncode$(Site$)
    else
      baseUrl$ = ""
    end if
  end if
  call disconnect
end sub

'
' Load in-line wiki tags into memory
'
sub loadWikiTags
  numInlineTags = 40

  for i = 0 to numInlineTags
    for j = 0 to 4
      read inlineTag$(i, j)
    next j
  next i

  ' Inline tags data
  data "======", "======", "<h1>"    , "</h1>"   , 1
  data "=====" , "=====" , "<h2>"    , "</h2>"   , 1
  data "===="  , "===="  , "<h3>"    , "</h3>"   , 1
  data "==="   , "==="   , "<h4>"    , "</h4>"   , 1
  data "=="    , "=="    , "<h5>"    , "</h5>"   , 1
  data "**"    , "**"    , "<b>"     , "</b>"    , 0
  data "//"    , "//"    , "<i>"     , "</i>"    , 0
  data "__"    , "__"    , "<u>"     , "</u>"    , 0
  data "^^"    , "^^"    , "<sup>"   , "</sup>"  , 0
  data ",,"    , ",,"    , "<sub>"   , "</sub>"  , 0
  data "'"     , "'"     , "<tt>"    , "</tt>"   , 0
  data "----"  , ""      , "<hr/>"   , ""        , 0
  data "++"    , "++"    , "<big>"   , "</big>"  , 0
  data "--"    , "--"    , "<small>" , "</small>", 0
  data "\\"    , ""      , "<br/>"   , ""        , 0
  data "(c)"   , ""      , "&copy;"  , ""        , 0
  data "(tm)"  , ""      , "&trade;" , ""        , 0
  data "(r)"   , ""      , "&reg;"   , ""        , 0
  data "<->"   , ""      , "&harr;"  , ""        , 0
  data "<=>"   , ""      , "&hArr;"  , ""        , 0
  data "->"    , ""      , "&rarr;"  , ""        , 0
  data "<-"    , ""      , "&larr;"  , ""        , 0
  data "=>"    , ""      , "&rArr;"  , ""        , 0
  data "<="    , ""      , "&lArr;"  , ""        , 0

  data "<error>",   "</error>",   "<span class=""text-error"">",   "</span>", 0
  data "<info>",    "</info>",    "<span class=""text-info"">",    "</span>", 0
  data "<muted>",   "</muted>",   "<span class=""muted"">",        "</span>", 0
  data "<success>", "</success>", "<span class=""text-success"">", "</span>", 0
  data "<warning>", "</warning>", "<span class=""text-warning"">", "</span>", 0

  data "<badge>",           "</badge>", "<span class=""badge"">",                 "</span>", 0
  data "<badge-important>", "</badge>", "<span class=""badge badge-important"">", "</span>", 0
  data "<badge-info>",      "</badge>", "<span class=""badge badge-info"">",      "</span>", 0
  data "<badge-inverse>",   "</badge>", "<span class=""badge badge-inverse"">",   "</span>", 0
  data "<badge-success>",   "</badge>", "<span class=""badge badge-success"">",   "</span>", 0
  data "<badge-warning>",   "</badge>", "<span class=""badge badge-warning"">",   "</span>", 0

  data "<label>",           "</label>", "<span class=""label"">",                 "</span>", 0
  data "<label-important>", "</label>", "<span class=""label label-important"">", "</span>", 0
  data "<label-info>",      "</label>", "<span class=""label label-info"">",      "</span>", 0
  data "<label-inverse>",   "</label>", "<span class=""label label-inverse"">",   "</span>", 0
  data "<label-success>",   "</label>", "<span class=""label label-success"">",   "</span>", 0
  data "<label-warning>",   "</label>", "<span class=""label label-warning"">",   "</span>", 0
end sub

'
' Render the Page Index page
'
sub pageIndex
  call connect
    #db execute("select distinct upper(substr(name, 1, 1)) letter from pages order by upper(name)")
    if #db hasanswer() then
      html "<p>"
      for i = 1 to #db rowcount()
        #row = #db #nextrow()
        letter$ = #row letter$()
        html "<a href=""#"; letter$; """>"; letter$; "</a> "
      next i
      html "</p>"
    end if

    letter$ = ""

    #db execute("select name from pages order by upper(name)")
    if #db hasanswer() then
      for i = 1 to #db rowcount()
        #row = #db #nextrow()
        pageName$ = #row name$()
        if letter$ <> upper$(left$(pageName$, 1)) then
          if letter$ <> "" then html "</p>"
          letter$ = upper$(left$(pageName$, 1))
          html "<h4><a name="""; letter$; """></a>"; letter$; "</h4><p>"
        end if
        link #exists, pageName$, loadPage
        #exists setid("link";i)
        #exists setkey(pageName$)
        html "<br />"
      next i
      html "</p>"
    end if
  call disconnect
end sub

'
' Render the list of pages for the top menu
'
sub pageList
  call connect
    #db execute("select name from pages where hide isnull or hide = 0 order by case when upper(name) = 'HOME' then 0 else 1 end, upper(name)")
    if #db hasAnswer() then
      count = #db rowcount()
      for i = 1 to count
        #row = #db #nextrow()
        pageName$ = #row name$()
        liClass$ = ""
        if currentName$ = pageName$ then liClass$ = liClass$ + "active"
        if liClass$ = "" then
          html "<li>"
        else
          html "<li class=""" + liClass$ + """>"
        end if
        link #exists, pageName$, loadPage
        #exists setid("page";i)
        #exists setkey(pageName$)
        html "</li>"
      next i
    end if
  call disconnect
end sub

'
' Render the search results page for the search string (string$)
'
sub pageSearch string$
  ' Build the search pattern
  pattern$ = "%"
  i = 1
  while 1
    w$ = trim$(word$(string$, i))
    if w$ = "" then exit while
    i = i + 1
    pattern$ = pattern$ + w$ + "%"
  wend
    
  sql$ = "select name, content from pages where name like ";quote$(pattern$);" or content like ";quote$(pattern$);" order by upper(name)"

  letter$ = ""
  call connect
    #db execute(sql$)
    if #db hasAnswer() then
      for i = 1 to #db rowcount()
        #row = #db #nextRow()
        pageName$ = #row name$()
        pageContent$ = #row content$()
        if letter$ <> upper$(left$(pageName$, 1)) then
          letter$ = upper$(left$(pageName$, 1))
          print
          html "<strong>"; letter$; "</strong>"
          print : print
        end if
        link #exists, pageName$, loadPage
        #exists setid("link";i)
        #exists setkey(pageName$)
        print
        start = instr(lower$(pageContent$), lower$(word$(string$, 1)))
        while mid$(pageContent$, start, 1) <> chr$(10) and start > 0
          start = start - 1
        wend
        endLine = instr(pageContent$ + chr$(10), chr$(10), start + 1)
        print mid$(pageContent$, start, endLine - start)
        print
      next i
    else
      print
      print "No pages containing """ + string$ + """ found."
    end if
  call disconnect
end sub

'
' Render the Recent Changes page
'
sub recentChanges
  today = date$("days")
  days = -1
  call connect
    #db execute("select date, name from pages order by date desc, time desc limit 10")
    if #db hasAnswer() then
      for i = 1 to #db rowcount()
        #row = #db #nextRow()
        changeDate = #row date()
        pageName$ = #row name$()
        if today - changeDate <> days then
          if days <> -1 then html "</p>"
          days = today - changeDate
          html "<h4>Changed "
          select case days
            case 0
              html "Today"
            case 1
              html "Yesterday"
            case else
              html days; " days ago"
          end select
          html "</h4><p>"
        end if
        link #exists, pageName$, loadPage
        #exists setid("link";i)
        #exists setkey(pageName$)
        html "<br />"
      next i
    end if
  call disconnect
end sub

'
' Render the string (content$)
'
sub renderPage content$

  ' Define some constants

  StartTag  = 0
  EndTag    = 1
  StartHTML = 2
  EndHTML   = 3
  BlockTag  = 4

  CR$ = chr$(13)
  NL$ = chr$(10)

  ' Reset stacks

  #tagStack initialise()
  #blockStack initialise()
  #htmlStack initialise()

  ' Reset flags

  newLineFlag = 1

  objectCount = 0

  ' Start processing

  i = 1
  while i <= len(content$)

    ' Ignore new lines
    if mid$(content$, i, 1) = NL$ then goto [skipChar]

    ' Things that happen after a new line

    if newLineFlag then
      newLineFlag = 0

      ' New paragraph
      if mid$(content$, i, 1) = CR$ then
        call closeCurrentBlock
        newLineFlag = 1
        ' Skip any subsequent NL's or CR's to avoid multiple paragraphs
        while mid$(content$, i, 1) = CR$ or mid$(content$, i ,1) = NL$
          i = i + 1
        wend
        goto [nextChar]
      end if

      ' New table or table row
      if mid$(content$, i, 1) = "|" or mid$(content$, i, 1) = "^" then
        if mid$(content$, i, 1) <> mid$(content$, i + 1, 1) then 
          if #blockStack peekHead$() = "</table>" then
            call unwindTagStack
            html #blockStack pop$()
            html #blockStack pop$()
          else
            call unwindBlockStack
            html "<table class=""table table-bordered table-striped"">"
            #blockStack push("</table>")
          end if
          html "<tr>"
          #blockStack push("</tr>")
          if mid$(content$, i, 1) = "|" then
            html "<td>"
            #blockStack push("</td>")
          else
            html "<th>"
            #blockStack push("</th>")
          end if
          goto [skipChar]
        end if
      end if

      ' New list of list item
      if mid$(content$, i, 1) = "*" and mid$(content$, i + 1, 1) <> "*" then
        if #blockStack peekHead$() = "</ul>" then
          call unwindTagStack
          html #blockStack pop$()
        else
          call unwindBlockStack
          html "<ul>"
          #blockStack push("</ul>")
        end if
        html "<li>"
        #blockStack push("</li>")
        goto [skipChar]
      end if

      ' New ordered list or list item
      if mid$(content$, i, 1) = "#" then
        if #blockStack peekHead$() = "</ol>" then
          call unwindTagStack
          html #blockStack pop$()
        else
          call unwindBlockStack
          html "<ol>"
          #blockStack push("</ol>")
        end if
        html "<li>"
        #blockStack push("</li>")
        goto [skipChar]
      end if

      ' New navigation list or navigation list item
      if mid$(content$, i, 1) = ">" and instr(">!=", mid$(content$, i + 1, 1)) > 0 then
        if #blockStack peekHead$() = "</ul>" and navListFlag then
          call unwindTagStack
          html #blockStack pop$()
        else
          call unwindBlockStack
          html "<ul class=""nav nav-list"">"
          #blockStack push("</ul>")
          navListFlag =1
        end if
        i = i + 1
        select case mid$(content$, i, 1)
          case ">" 
            html "<li>"
          case "!" 
            html "<li class=""active"">"
          case "=" 
            html "<li class=""nav-header"">"
        end select
        #blockStack push("</li>")
        goto [skipChar]
      end if

      html " "
    end if

    ' Carrige Return
    if mid$(content$, i, 1) = CR$ then
      newLineFlag = 1
      goto [skipChar]
    end if

    ' Table tags

    if #blockStack peekHead$() = "</table>" then
      if mid$(content$, i, 1) = "|" or mid$(content$, i, 1) = "^" then
        if mid$(content$, i, 1) <> mid$(content$, i + 1, 1) then 
          call unwindTagStack
          html #blockStack pop$()
          if mid$(content$, i, 1) = "|" then
            html "<td>"
            #blockStack push("</td>")
          else
            html "<th>"
            #blockStack push("</th>")
          end if
          goto [skipChar]
        end if
      end if
    end if

    ' Alert boxes
    if mid$(content$, i, 8) = "</alert>" then
      call unwindBlockStack
      i = i + 8
      goto [nextChar]
    end if
      
    if mid$(content$, i, 7) = "<alert>" then
      call unwindBlockStack
      html "<div class=""alert"">"
      #blockStack push("</div>")
      i = i + 7
      goto [nextChar]
    end if

    if mid$(content$, i, 14) = "<alert-danger>" then
      call unwindBlockStack
      html "<div class=""alert alert-danger"">"
      #blockStack push("</div>")
      i = i + 14
      goto [nextChar]
    end if

    if mid$(content$, i, 13) = "<alert-error>" then
      call unwindBlockStack
      html "<div class=""alert alert-error"">"
      #blockStack push("</div>")
      i = i + 13
      goto [nextChar]
    end if

    if mid$(content$, i, 12) = "<alert-info>" then
      call unwindBlockStack
      html "<div class=""alert alert-info"">"
      #blockStack push("</div>")
      i = i + 12
      goto [nextChar]
    end if

    if mid$(content$, i, 15) = "<alert-success>" then
      call unwindBlockStack
      html "<div class=""alert alert-success"">"
      #blockStack push("</div>")
      i = i + 15
      goto [nextChar]
    end if

    if mid$(content$, i, 15) = "<alert-warning>" then
      call unwindBlockStack
      html "<div class=""alert alert-warning"">"
      #blockStack push("</div>")
      i = i + 15
      goto [nextChar]
    end if

    ' Hero Unit
    if mid$(content$, i, 7) = "</hero>" then
      call unwindBlockStack
      i = i + 7
      goto [nextChar]
    end if

    if mid$(content$, i, 6) = "<hero>" then
      call unwindBlockStack
      html "<div class=""hero-unit"">"
      #blockStack push("</div>")
      i = i + 6
      goto [nextChar]
    end if

    ' Hide a section
    if mid$(content$, i, 6) = "<hide>" then
      j = instr(content$ + "</hide>", "</hide>", i + 6)
      i = j + 7
      goto [nextChar]
    end if

    ' Embedded object
    if mid$(content$, i, 8) = "<object>" then
      j = instr(content$ + "</object>", "</object>", i + 8)
      name$ = mid$(content$, i + 8, j - i - 8)
      i = j + 9
      if allowObjects = 0 then
        html "<span class=""label label-warning"">Objects have been disabled on this site.</span>"
      else
        if projectExists(name$) then
          run name$, #object
          render #object
        else
          html "<span class=""label label-important"">Cannot find object "
          print name$;
          html ".</span>"
        end if
      end if
      goto [nextChar]
    end if

    ' Plugin
    if mid$(content$, i, 8) = "<plugin>" then
      j = instr(content$ + "</plugin>", "</plugin>", i + 8)
      name$ = mid$(content$, i + 8, j - i - 8)
      i = j + 9
      if allowPlugins = 0 then
        html "<span class=""label label-warning"">Plugins have been disabled on this site.</span>"
      else
        j = instr(name$, " ")
        if j <> 0 then
          PluginParams$ = mid$(name$, j + 1)
          name$ = left$(name$, j - 1)
        end if
        if projectExists(name$) then
          run name$, #object
          if #object isblock() then
            call closeCurrentBlock
          else
            call newParaNeeded
          end if
          #object main(#self, #user)
          render #object
        else
          html "<span class=""label label-important"">Cannot find plugin "
          print name$;
          html ".</span>"
        end if
      end if
      goto [nextChar]
    end if

    ' File block
    if mid$(content$, i, 6) = "<file>" then
      call unwindBlockStack
      j = instr(content$ + "</file>", "</file>", i + 6)
      text$ = mid$(content$, i + 6, j - i - 6)
      i = j + 7
      html "<pre class=""file"">"
      print text$;
      html "</pre>"
      goto [nextChar]
    end if

    ' Code block
    if mid$(content$, i, 6) = "<code>" then
      call unwindBlockStack
      j = instr(content$ + "</code>", "</code>", i + 6)
      text$ = mid$(content$, i + 6, j - i - 7)
      i = j + 7
      html "<pre class=""code"">"
      print text$;
      html "</pre>"
      goto [nextChar]
    end if

    ' ===========
    ' Inline tags
    ' ===========

    ' Hash tag #word (but not #word# which is heading 6)
    if mid$(content$, i, 1) = "#" and isAlpha(mid$(content$, i + 1, 1)) then
      for j = i + 2 to len(content$)
        if not(isAlphaNum(mid$(content$, j, 1))) then
          j = j - 1
          exit for
        end if
      next j
      if j > i and mid$(content$, j + 1, 1) <> "#" then
        word$ = mid$(content$, i + 1, j - i)
        link #hashtag, word$, [findHashTag]
        #hashtag setid("link";linkCount)
        linkCount = linkCount + 1
        #hashtag setkey(word$)
        i = j + 1
        goto [nextChar]
      end if
    end if

    if #tagStack hasdata() then
      ' Check for end tag

      endTag$ = #tagStack peek$()
      if mid$(content$, i, len(endTag$)) = endTag$ then
        #tagStack pop$()
        for j = 0 to numInlineTags
          if inlineTag$(j, EndTag) = endTag$ then
            if inlineTag$(j, BlockTag) = "1" then
              call unwindTagStack
              html #blockStack pop$()
            else
              html #htmlStack pop$()
            end if
            exit for
          end if
        next j
        i = i + len(endTag$)
        goto [nextChar]
      end if
    end if

    ' Check for start tag
    for j = 0 to numInlineTags
      tag$ = inlineTag$(j, StartTag)
      if mid$(content$, i, len(tag$)) = tag$ then
        if inlineTag$(j, BlockTag) = "1" then
          call closeCurrentBlock
        else
          call newParaNeeded
        end if
        html inlineTag$(j, StartHTML)
        i = i + len(tag$)
        ' Push the end tag onto the stack if required
        if inlineTag$(j, EndTag) <> "" then
          #tagStack push(inlineTag$(j, EndTag))
          if inlineTag$(j, BlockTag) = "1" then
            #blockStack push(inlineTag$(j, EndHTML))
          else
            #htmlStack push(inlineTag$(j, EndHTML))
          end if
        end if
        goto [nextChar]
      end if
    next j

    call newParaNeeded

    ' Ignore wiki markup %%
    if mid$(content$, i, 2) = "%%" then
      j = instr(content$ + "%%", "%%", i + 2)
      text$ = mid$(content$, i + 2, j - i - 2)
      i = j + 2
      print text$;
      goto [nextChar]
    end if

    ' Word definition ((word|text))
    if mid$(content$, i, 2) = "((" then
      j = instr(content$, "))", i + 2)
      if j = 0 then goto [processChar]
      word$ = trim$(mid$(content$, i + 2, j - i - 2))
      i = j + 2
      ' Check for vertical bar
      j = instr(word$, "|")
      if j > 0 then
        text$ = trim$(mid$(word$, j + 1))
        word$ = trim$(left$(word$, j - 1))
      else
        text$ = word$
      end if
      html "<abbr title="""
      print text$;
      html """>"
      print word$;
      html "</abbr>"
      goto [nextChar]
    end if

    ' An image {{url|text|options}}
    if mid$(content$, i, 2) = "{{" then
      text$ = ""
      imgAlign$ = ""
      imgClass$ = ""
      imgSize$ = ""
      lighbox = 0
      j = instr(content$, "}}", i + 2)
      if j = 0 then goto [processChar]
      url$ = trim$(mid$(content$, i + 2, j - i - 2))
      i = j + 2
      ' Check for vertical bar
      j = instr(url$, "|")
      if j > 0 then
        text$ = trim$(mid$(url$, j + 1))
        url$ = trim$(mid$(url$, 1, j - 1))
        ' Check for options
        j = instr(text$, "|")
        if j > 0 then
          options$ = lower$(trim$(mid$(text$, j + 1)))
          text$ = trim$(mid$(text$, 1, j - 1))
          k = 1
          opt$ = word$(options$, k)
          while opt$ <> ""
            select case opt$
              case "left"
                imgAlign$ = "left"
              case "right"
                imgAlign$ = "right"
              case "rounded"
                imgClass$ = "img-rounded"
              case "circle"
                imgClass$ = "img-circle"
              case "polaroid"
                imgClass$ = "img-polaroid"
              case "lightbox"
                lightbox = 1
              case else
                if isValidSize(opt$) then imgSize$ = opt$
            end select
            k = k + 1
            opt$ = word$(options$, k)
          wend
        else
          options$ = ""
        end if
      end if

      ' Internal link?
      if lower$(left$(url$, 7)) <> "http://" and lower$(left$(url$, 8)) <> "https://" then
        if text$ = "" then text$ = url$
        if imgSize$ <> "" then
          originalUrl$ = "/" + Site$ + "/" + url$
          url$ = makeThumbnail$(url$, imgSize$)
        else
          url$ = "/" + Site$ + "/" + url$
        end if
      end if

      ' Image or other file type?
      select case lower$(right$(url$, 4))
      case ".gif", ".jpg", ".png"
        if lightbox then
          imgId = int(rnd(1) * 100)
          html "<a href=""#lightbox";imgId;""" data-toggle=""lightbox"">"
        end if
        html "<img src="""
        print url$;
        html """"
        if imgClass$ <> "" then html " class="""; imgClass$; """"
        if text$ <> "" then
          html " title="""
          if lightbox then
            print "Click on image to enlarge";
          else
            print text$;
          end if
          html """ alt="""
          if lightbox then
            print "Click on image to enlarge";
          else
            print text$;
          end if
          html """"
        end if
        if imgAlign$ <> "" then html " align="""; imgAlign$; """"
        html " />"
        if lightbox then
          lightboxScript = 1
          html "</a>"
          PostBlockHTML$ = PostBlockHTML$ + "<div id=""lightbox";imgId;""" class=""lightbox hide fade"" tabindex=""-1"" role=""dialog"" aria-hidden=""true""><div class=""lightbox-header""><button type=""button"" class=""close"" data-dismiss=""lightbox"" aria-hidden=""true"">&times;</button></div><div class=""lightbox-content""><img src="""; originalUrl$; """>"
          if text$ <> "" then PostBlockHTML$ = PostBlockHTML$ + "<div class=""lightbox-caption""><p>";text$;"</p></div>"
          PostBlockHTML$ = PostBlockHTML$ + "</div></div>"
        end if
      case else
        buttonClass$ = validateButtonClass$(options$)
        html "<a href="""
        print url$;
        html """"
        if buttonClass$ <> "" then html " class="""; buttonClass$; """" 
        html ">"
        if text$ <> "" then
          print text$;
        else
          print url$;
        end if
        html "</a>"
      end select
      goto [nextChar]
    end if

    ' A link [[url|text]]
    if mid$(content$, i, 2) = "[[" then
      j = instr(content$, "]]", i + 2)
      if j = 0 then goto [processChar]
      i = i + 2
      url$ = trim$(mid$(content$, i, j - i))
      i = j + 2
      ' Check for vertical bar
      j = instr(url$, "|")
      if j > 0 then
        text$ = trim$(mid$(url$, j + 1))
        url$ = trim$(left$(url$, j - 1))
        if mid$(text$, 1, 2) = "{{" and mid$(text$, len(text$) - 1) = "}}" then
          ' Image link
          imgUrl$ = trim$(mid$(text$, 3, len(text$) - 4))
          j = instr(imgUrl$, "|")
          if j > 0 then
            text$ = trim$(mid$(imgUrl$, j + 1))
            imgUrl$ = trim$(left$(imgUrl$, j - 1))
          else
            text$ = imgUrl$
          end if
          if lower$(left$(imgUrl$, 7)) <> "http://" and lower$(left$(imgUrl$, 8)) <> "https://" then
            imgUrl$ = "/" + Site$ + "/" + imgUrl$
          end if
        else
          imgUrl$ = ""
          j = instr(text$, "|")
          if j > 0 then
            buttonClass$ = validateButtonClass$(trim$(mid$(text$, j + 1)))
            text$ = trim$(left$(text$, j - 1))
          else
            buttonClass$=""
          end if
        end if
      else
        imgUrl$ = ""
        text$ = ""
        buttonClass$ = ""
      end if
      ' External link, ftp or mailto link?
      if lower$(left$(url$, 7)) = "http://" or lower$(left$(url$, 8)) = "https://" or lower$(left$(url$, 4)) = "ftp:" or lower$(left$(url$, 7)) = "mailto:" then
        html "<a href="""
        print url$;
        html """"
        if newWindow and (lower$(left$(url$, 7)) = "http://" or lower$(left$(url$, 8)) = "https://") then html " target=""_blank"""
        if buttonClass$ <> "" then html " class="""; buttonClass$; """"
        html ">"
        if imgUrl$ <> "" then
          html "<img src="""
          html imgUrl$
          html """"
          if text$ <> "" then
            html " alt="""
            print text$;
            html """"
          end if
          html " border=""0"">"
        else
          if text$ <> "" then
            print text$;
          else
            print url$;
          end if
        end if
        html "</a>"
      else
        if pageExists(url$) then
          if imgUrl$ <> "" then
            imagebutton #exists, imgUrl$, loadPage
          else
            if text$ <> "" then
              link #exists, text$, loadPage
            else
              link #exists, url$, loadPage
            end if
            #exists setid("link";linkCount)
            linkCount = linkCount + 1
            if buttonClass$ <> "" then #exists cssclass(buttonClass$)
          end if
          #exists setkey(url$)
        else
          if imgUrl$ <> "" then
            imagebutton #doesntExist, imgUrl$, [createPage]
          else
            if text$ <> "" then
              link #doesntExist, "?" + text$, [createPage]
            else
              link #doesntExist, "?" + url$, [createPage]
            end if
            #doesntExist setid("link";linkCount)
            linkCount = linkCount + 1
            if buttonClass$ <> "" then #doesntExist cssclass(buttonClass$)
          end if
          #doesntExist setkey(url$)
        end if
      end if
      goto [nextChar]
    end if

    ' A link to an application <<name?args|text>>
    if mid$(content$, i, 2) = "<<" then
      j = instr(content$, ">>", i + 2)
      if j = 0 then goto [processChar]
      i = i + 2
      app$ = trim$(mid$(content$, i, j - i))
      i = j + 2
      ' Check for vertical bar
      j = instr(app$, "|")
      if j > 0 then
        text$ = trim$(mid$(app$, j + 1))
        app$ = trim$(left$(app$, j - 1))
        if left$(text$, 2) = "{{" and mid$(text$, len(text$) - 1) = "}}" then
          ' Image link
          imgUrl$ = trim$(mid$(text$, 3, len(text$) - 4))
          j = instr(imgUrl$, "|")
          if j > 0 then
            text$ = trim$(mid$(imgUrl$, j + 1))
            imgUrl$ = trim$(left$(imgUrl$, j - 1))
          else
            text$ = imgUrl$
          end if
          if lower$(left$(imgUrl$, 7)) <> "http://" and lower$(left$(imgUrl$, 8)) <> "https://" then
            imgUrl$ = "/" + Site$ + "/" + imgUrl$
          end if
        else
          imgUrl$ = ""
          j = instr(text$, "|")
          if j > 0 then
            buttonClass$ = validateButtonClass$(trim$(mid$(text$, j + 1)))
            text$ = trim$(left$(text$, j - 1))
          else
            buttonClass$=""
          end if
        end if
      else
        imgUrl$ = ""
        text$ = ""
        buttonClass$ = ""
      end if
      j = instr(app$, " ")
      if j > 0 then
        arg$ = trim$(mid$(app$, j + 1))
        app$ = trim$(left$(app$, j - 1))
      else
        arg$ = ""
      end if
      if projectExists(app$) then
        html "<a href=""/seaside/go/runbasicpersonal?app="
        print app$;
        if arg$ <> "" then print "&"; arg$;
        html """"
        if newWindow then html " target=""_blank"""
        if buttonClass$ <> "" then html " class="""; buttonClass$; """"
        html ">"
        if imgUrl$ <> "" then
          html "<img src="""
          html imgUrl$
          html """"
          if text$ <> "" then
            html " alt="""
            print text$;
            html """"
          end if
          html " border=""0"">"
        else
          if text$ <> "" then
            print text$;
          else
            print app$;
          end if
        end if
        html "</a>"
      else
        print "Cannot find application "; app$; ".";
      end if
      goto [nextChar]
    end if

    ' A bare url http[s]://{url}
    if lower$(mid$(content$, i, 7)) = "http://" or lower$(mid$(content$, i, 8)) = "https://" then
      j = min(instr(content$ + " ", " ", i), instr(content$ + CR$, CR$, i))
      html "<a href="""
      print mid$(content$, i, j - i);
      html """"
      if newWindow then html " target=""_blank"""
      html ">"
      print mid$(content$, i, j - i);
      html "</a>"
      i = j
      goto [nextChar]
    end if

    ' A bare url www.something
    if lower$(mid$(content$, i, 4)) = "www." then
      j = min(instr(content$ + " ", " ", i), instr(content$ + CR$, CR$, i))
      html "<a href=""http://"
      print mid$(content$, i, j - i);
      html """"
      if newWindow then html " target=""_blank"""
      html ">"
      print mid$(content$, i, j - i);
      html "</a>"

      i = j
      goto [nextChar]
    end if

    ' Just output the character
    [processChar]
    print mid$(content$, i, 1);

    [skipChar]
    i = i + 1

    [nextChar]
  wend
  call unwindBlockStack
end sub

'
' Close the current block, unless in a table or list in which case close all open blocks
'
sub closeCurrentBlock
  if #blockStack peekHead$() = "</table>" or #blockStack peekHead$() = "</ul>" or #blockStack peekHead$() = "</ol>" then
    call unwindBlockStack
  else
    call unwindTagStack
    if #blockStack peek$() <> "</div>" then html #blockStack pop$()
  end if
end sub

'
' Decide if a new paragraph is required
'
sub newParaNeeded
  if #blockStack peek$() = "" or #blockStack peek$() = "</div>" then
    html "<p>"
    #blockStack push("</p>")
  end if
end sub

'
' Close off all in-line and block tags. Emit the post-block HTML if required
'
sub unwindBlockStack
  call unwindTagStack
  while #blockStack hasdata()
    html #blockStack pop$()
  wend
  if PostBlockHTML$ <> "" then
    html PostBlockHTML$
    PostBlockHTML$ = ""
  end if
end sub

'
' Close off all open in-line tags
'
sub unwindTagStack
  while #htmlStack hasdata()
    html #htmlStack pop$()
  wend
  #tagStack initialise()
end sub

' ===================
' ==== FUNCTIONS ====
' ===================

'
' Return the string (s$) with the message (m$) appended to it
'
function appendMessage$(s$, m$)
  if s$ = "" then
    appendMessage$ = m$
  else
    appendMessage$ = s$ + "<br/>" + m$
  end if
end function

'
' Return the final component of the path (name$) using (sep$) as the path separator
'
function basename$(name$, sep$)
  for i = len(name$) to 0 step -1
    if mid$(name$, i, 1) = sep$ then exit for
  next i
  basename$ = mid$(name$, i + 1)
end function

'
' PLUGIN FUNCTION: Return the name of the current page
'
function currentPage$()
  currentPage$ = currentName$
end function

'
' Return the content of the current page
'
function currentPageContent$()
  if preview then
    currentPageContent$ = newContent$
  else
    currentPageContent$ = currentContent$
  end if
end function

'
' PLUGIN FUNCTION: Return the name of the current page
'
function currentPageName$()
  currentPageName$ = currentName$
end function

'
' Return the sidebar content of the current page
'
function currentSidebarContent$()
  if preview then
    currentSidebarContent$ = newSidebarContent$
  else
    currentSidebarContent$ = sidebarContent$
  end if
end function

function databaseName$()
  databaseName$ = DatabaseFilename$
end function

'
' Return the string (s$) with all quotes (') changed to ('')
'
function doubleQuote$(s$)
  if instr(s$, "'") then
    for i = 1 to len(s$)
      if mid$(s$, i, 1) = "'" then doubleQuote$ = doubleQuote$ + "'"
      doubleQuote$ = doubleQuote$ + mid$(s$, i, 1)
    next i
  else
    doubleQuote$ = s$
  end if
end function

'
' Return true if the directory (dirname$) exists
'
function dirExists(dirname$)
  files #dir, dirname$
  if #dir hasanswer() then
    #dir nextfile$()
    dirExists = #dir isdir()
  end if
end function

'
' Return true if the file (filename$) exists
'
function fileExists(filename$)
  files #file, filename$
  if #file hasanswer() then
    #file nextfile$()
    fileExists = not(#file isdir())
  end if
end function

'
' Return the date (d$) formatted according to the wiki date format
'
function formatDate$(d$)
  if len(d$) = 10 then
    if mid$(d$, 5, 1) = "-" then
      ' YYYY-MM-DD
      dd$ = mid$(d$, 9, 2)
      mm$ = mid$(d$, 6, 2)
      yyyy$ = mid$(d$, 1, 4)
    else
      ' MM/DD/YYYY
      dd$ = mid$(d$, 4, 2)
      mm$ = mid$(d$, 1, 2)
      yyyy$ = mid$(d$, 7, 4)
    end if
    yy$ = mid$(yyyy$, 3, 2)

    i = 1
    while i <= len(dateFormat$)
      if mid$(dateFormat$, i, 4) = "yyyy" then
        formatDate$ = formatDate$ + yyyy$
        i = i + 4
      else
        select case mid$(dateFormat$, i, 2)
          case "dd"
            formatDate$ = formatDate$ + dd$
            i = i + 2
          case "mm"
            formatDate$ = formatDate$ + mm$
            i = i + 2
          case "yy"
            formatDate$ = formatDate$ + yy$
            i = i + 2
          case else
            formatDate$ = formatDate$ + mid$(dateFormat$, i, 1)
            i = i + 1
        end select
      end if
    wend
  else
    formatDate$ = d$
  end if
end function

'
' Return the time (t) formatted as 'hh:mm:ss'
'
function formatTime$(t)
  days = int(t / 86400)
  t = t - (days * 86400)
  hh = int(t / 3600)
  mm = int((t - hh * 3600) / 60)
  ss = t - (hh * 3600) - (mm * 60)

  formatTime$ = str$(hh) + ":" + right$("0" + str$(mm), 2) + ":" + right$("0" + str$(ss), 2)
end function

'
' PLUGIN FUNCTION: Return the application name
'
function getAppName$()
  getAppName$ = AppName$
end function

'
' PLUGIN FUNCTION: Return the site name
'
function getSiteName$()
  getSiteName$ = Site$
end function

'
' PLUGIN FUNCTION: Return the path separator
'
function getPathSeparator$()
  getPathSeparator$ = pathSeparator$
end function

'
' PLUGIN FUNCTION: Return the Projects directory path
'
function getProjectsRoot$()
  getProjectsRoot$ = ProjectsRoot$
end function

'
' PLUGIN FUNCTION: Return the Public directory path
'
function getResourcesRoot$()
  getResourcesRoot$ = ResourcesRoot$
end function

'
' PLUGIN FUNCTION: Return the upload directory path
'
function getUploadDir$()
  getUploadDir$ = uploadDir$
end function

'
' Return value of the URL parameter specified by key$
'
function getUrlParam$(key$)
  for i = 1 to 999
    w$ = word$(UrlKeys$, i, "&")
    if w$ = "" then exit for
    k$ = word$(w$, 1, "=")
    if upper$(key$) = upper$(k$) then
      getUrlParam$ = word$(w$, 2, "=")
      exit for
    end if
  next
  getUrlParam$ = urlDecode$(getUrlParam$)
end function

'
' PLUGIN FUNCTION: Return the email address of the logged in user
'
function getUserAddress$()
  getUserAddress$ = UserAddress$
end function

'
' Return true if user (id) is a wiki administrator
'
function isAdmin(id)
  if id <> 0 then
    call connect
    #db execute("select 1 from admins where id = " + str$(id))
    if #db hasanswer() then isAdmin = 1
    call disconnect
  end if
end function

'
' Return true if string (str$) is only composed of letters (a-z,A-Z)
'
function isAlpha(str$)
  isAlpha = 1
  for i = 1 to len(str$)
    c$ = mid$(str$, i, 1)
    if not(c$ >= "a" and c$ <= "z") and not(c$ >= "A" and c$ <= "Z") then
      isAlpha = 0
      exit for
    end if
  next i
end function

'
' Return true if string (str$) is only composed of letters (a-z,A-Z) or numbers [0-9]
'
function isAlphaNum(str$)
  isAlphaNum = 1
  for i = 1 to len(str$)
    c$ = mid$(str$, i, 1)
    if not(c$ >= "a" and c$ <= "z") and not(c$ >= "A" and c$ <= "Z") and not(c$ >= "0" and c$ <= "9") then
      isAlphaNum = 0
      exit for
    end if
  next i
end function

'
' Return true if string (size$) is a valid size specification
'
function isValidSize(size$)
  size$ = trim$(size$)
  if right$(size$, 1) = "%" then
    ' Percentage
    p = val(left$(size$, len(size$) - 1))
    if p > 0 then isValidSize = 1
  else
    i = instr(size$, "x")
    if i > 1 then
      ' Dimension
      x = val(left$(size$, i - 1))
      y = val(mid$(size$, i + 1))
      if x > 0 and y > 0 then isValidSize = 1
    end if    
  end if
end function

'
' Create an thumbnail of image (image$) re-sized to (size$) return the thumbnails URL
'
function makeThumbnail$(image$, size$)
  if size$ <> "" then
    original$ = uploadDir$ + pathSeparator$ + image$
    thumbnail$ = uploadDir$ + pathSeparator$ + "thumbnails" + pathSeparator$ + replacePct$(size$) + "_" + image$
    files #original, original$
    if #original hasanswer() then
      #original nextfile$()
      #original dateformat("yyyy-mm-dd")
      originalTimestamp$ = #original date$() + #original time$()
      files #thumbnail, thumbnail$
      if #thumbnail hasanswer() then
        #thumbnail nextfile$()
        #thumbnail dateformat("yyyy-mm-dd")
        thumbnailTimestamp$ = #thumbnail date$() + #thumbnail time$()
      end if
      if originalTimestamp$ > thumbnailTimestamp$ then
        if Platform$ = "win32" then
          command$ = ProjectsRoot$ + pathSeparator$ + AppName$ + "_project" + pathSeparator$ + "win32" + pathSeparator$ + "convert.exe"
        else
          command$ = "convert"
        end if
        a$ = shell$(command$; " """; original$; """ -resize """; size$; ">"" """; thumbnail$; """")
      end if
    end if
    makeThumbnail$ = "/" + Site$ + "/thumbnails/" + replacePct$(size$) + "_" + image$
  else
    makeThumbnail$ = "/" + Site$ + "/" + image$
  end if
end function

'
' Return true if the page (name$) exists
'
function pageExists(name$)
  call connect
  #db execute("select * from pages where upper(name) = upper('"; doubleQuote$(name$); "')")
  pageExists = #db hasAnswer()
  call disconnect
end function

'
' PLUGIN FUNCTION: Return the plugin parameters
'
function pluginParameters$()
  pluginParameters$ = PluginParams$
end function

'
' Return true if the project (project$) exists
'
function projectExists(project$)
  projectExists = dirExists(ProjectsRoot$; pathSeparator$; project$; "_project")
end function

'
' Return the string (s$) quoted for use in sqlite queries
'
function quote$(s$)
  quote$ = "'" + doubleQuote$(s$) + "'"
end function

'
' Returns the string (s$) with the '%' character replaced with 'pct'
'
function replacePct$(s$)
  if right$(s$, 1) = "%" then
    replacePct$ = left$(s$, len(s$) - 1) + "pct"
  else
    replacePct$ = s$
  end if
end function

'
' Returns true if the page is a system generated page
'
function specialPage(name$)
  if name$ = "Page Index" or name$ = "Recent Changes" or name$ = "Search Results" then specialPage = 1
end function

'
' Return the URL decoded version of s$
'
function urlDecode$(s$)
  i = 1
  while i <= len(s$)
    c$ = mid$(s$, i, 1)
    if c$ = "+" then
      ' Convert + to space
      c$ = " "
    end if
    if c$ = "%" then
      ' Found an encoded character
      d$ = mid$(s$, i + 1, 2)
      h = hexdec(d$)
      if h <> 0 then
        c$ = chr$(h)
        i = i + 2
      end if
    end if
    urlDecode$ = urlDecode$ + c$
    i = i + 1
  next
end function

'
' Return the URL encoded version of s$
'
function urlEncode$(s$)
  for i = 1 to len(s$)
    c$ = mid$(s$, i, 1)
    if instr(" !*'();:@&=+$,/?%#[]", c$) <> 0  then
      urlEncode$ = urlEncode$ + "%" + dechex$(asc(c$))
    else
      urlEncode$ = urlEncode$ + c$
    end if
  next i
end function

'
' Takes string (class$) and returns the corresponding CSS button classes
'
function validateButtonClass$(class$)
  i = 1
  w$ = lower$(word$(class$, i))
  while w$ <> ""
    if w$ = "default" or w$ = "primary" or w$ = "info" or w$ = "success" or w$ = "warning" or w$= "danger" or w$ = "inverse" or w$ = "large" or w$ = "small" or w$ = "mini" then
      if validateButtonClass$ = "" then validateButtonClass$ = "btn"
      if w$ <> "default" then  validateButtonClass$ = validateButtonClass$ + " btn-" + w$
    end if
    i = i + 1
    w$ = lower$(word$(class$, i))
  wend
end function
