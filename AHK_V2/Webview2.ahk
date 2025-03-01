; Current WebView2 Include
; For Version 2.0-beta.1
On_ReSize(controller,*){
    If(wvLeft+wvTop+wvRight+wvBottom>0)
        DllCall "SetRect","ptr",RECT,"int",wvLeft,"int",wvTop,"int",wvRight,"int",wvBottom
    Else
        DllCall "GetClientRect","ptr",AHKGui.hWnd,"ptr",RECT
    NumPut "int",wvLeft,RECT
    NumPut "int",wvTop,RECT,4
    NumPut "int",NumGet(RECT,8,"int")-wvLeft,RECT,8
    NumPut "int",NumGet(RECT,12,"int")-wvTop,RECT,12
    ; IWebView2WebViewController::put_Bounds
    ComCall 6,controller,"ptr",RECT
}

QueryInterface(this,riid,ppvObject){
    ; Not used
}

AddRef(this){
    NumPut "uint",ObjAddRef(this),this,A_PtrSize
}

Release(this){
    NumPut "uint",ObjRelease(this),this,A_PtrSize
}

Invoke(this,HRESULT,iObject){
    global CoreWebView2
    Switch(this){
        Case WebView2Environment:
            ; iObject = ICoreWebView2Environment
            ; ICoreWebView2Environment::CreateCoreWebView2Controller
            ComCall 3,iObject,"ptr",AHKGui.hWnd,"ptr",WebView2Controller
        Case WebView2Controller:
            ; iObject = IWebView2WebViewController
            ObjAddRef iObject
            AHKGui.OnEvent "Size",On_ReSize.Bind(iObject)
            ; Resize Or Set WebView to fit the bounds of the parent window.
            If(wvLeft+wvTop+wvRight+wvBottom>0)
                DllCall "SetRect","ptr",RECT,"int",wvLeft,"int",wvTop,"int",wvRight,"int",wvBottom
            Else
                DllCall "GetClientRect","ptr",AHKGui.hWnd,"ptr",RECT
            ; IWebView2WebViewController::put_Bounds
            ComCall 6,iObject,"ptr",RECT
            ; IWebView2WebViewController::put_ZoomFactor
            ComCall 8,iObject,"double",ZoomFactor
            ; IWebView2WebViewController::get_CoreWebView2
            ComCall 25,iObject,"ptr*",&iCoreWebView2 := 0
            CoreWebView2 := iCoreWebView2
            ; ICoreWebView2::add_NavigationCompleted
            ComCall 15,CoreWebView2,"ptr",WebView2NavigationCompletedEventHandler,"uint64",token := 0
            ; ICoreWebView2::add_DocumentTitleChanged
            ComCall 46,CoreWebView2,"ptr",WebView2DocumentTitleChangedEventHandler,"uint64",token := 0
            If(NavUri)
                ; ICoreWebView2::Navigate
                ComCall 5,CoreWebView2,"str",NavUri
            Else If(NavStr)
                ; ICoreWebView2::NavigateToString
                ComCall 6,CoreWebView2,"str",NavStr
            If DevTool
                ; ICoreWebView2::OpenDevToolsWindow
                ComCall 51,CoreWebView2
        Case WebView2NavigationCompletedEventHandler:
            If(jsCode)
                ; ICoreWebView2::ExecuteScript
                ComCall 29,CoreWebView2,"str",jsCode,"ptr",WebView2ExecuteScriptCompletedHandler
            If(HostName){
                If(ObjGetCapacity(HostObj)){
                    objBuf      := Buffer(24,0)
                    ahkObject   := ComValue(0x400C,objBuf.ptr)    ;VT_BYREF VT_VARIANT
                    ahkObject[] := HostObj
                    ; ICoreWebView2::AddHostObjectToScript
                    ComCall 49,CoreWebView2,"str",HostName,"ptr",ahkObject
                }Else{
                    MsgBox "HostObj Not Created....","Object Error!","iconi"
                    ExitApp
                }
            }
        Case WebView2DocumentTitleChangedEventHandler:
            If(Type(Event_Name)="Func"){
                ; ICoreWebView2::get_DocumentTitle
                ComCall 48,CoreWebView2,"str*",&DocTitle := 0
                Event_Name.Call(DocTitle)
            }
    }
}

; Run jScript on the fly
Run_JS(Code){
    ; ICoreWebView2::ExecuteScript
    ComCall 29,CoreWebView2,"str",Code,"ptr",WebView2ExecuteScriptCompletedHandler
}

; Main vtable Object Setup
WebView2(){
    Static vtbl := []
    vtbl.Push Buffer(4*A_PtrSize)
    For Method In [QueryInterface,AddRef,Release,Invoke]
        NumPut "uptr",CallbackCreate(Method),vtbl[vtbl.Length],(A_Index-1)*A_PtrSize
    ptr := DllCall("GlobalAlloc","uint",64,"ptr",A_PtrSize+4,"uptr")
    NumPut "uptr",vtbl[vtbl.Length].ptr,ptr
    NumPut "uint",1,ptr,A_PtrSize
    Return ptr
}

; One Main Function For WebView2 Setup
WebView2_Init(iGui){
    global
    AHKGui                                   := iGui
    WebView2Environment                      := WebView2()     ; IWebView2CreateWebView2EnvironmentCompletedHandler.
    WebView2Controller                       := WebView2()     ; ICoreWebView2CreateCoreWebView2ControllerCompletedHandler.
    WebView2NavigationCompletedEventHandler  := WebView2()     ; ICoreWebView2NavigationCompletedEventHandler
    WebView2ExecuteScriptCompletedHandler    := WebView2()     ; ICoreWebView2ExecuteScriptCompletedHandler
    WebView2DocumentTitleChangedEventHandler := WebView2()     ; ICoreWebView2DocumentTitleChangedEventHandler.

    local dllPath := A_ScriptDir "\..\webview2\WebView2Loader"
    DllCall dllPath "\CreateCoreWebView2Environment","ptr",WebView2Environment

    If(A_LastError){
        local buf := Buffer(8,0)
        DllCall "FormatMessage","uint",256|4096,"ptr",0,"uint",A_LastError,"uint",0,"ptr",buf.ptr,"uint",0,"ptr",0
        msgbox "Error " A_LastError " = " StrGet(NumGet(buf,"ptr"))
        ExitApp
    }
}

; WebView2 Globals To Make AHK Gui Execute Your Code
NavUri := "",NavStr := "",RECT := Buffer(16,0),Event_Name := "",jsCode := "",HostName := "",HostObj := {}
ZoomFactor := 1.25,wvLeft := 0,wvTop := 0,wvRight := 0,wvBottom := 0,DevTool := False,AHKGui := ""
