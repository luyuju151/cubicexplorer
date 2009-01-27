unit CE_AddressToolbar;

interface

uses
  // CE Units
  CE_Breadcrumb, fCE_FolderTreeForm, CE_VistaFuncs, CE_GlobalCtrl,
  CE_SettingsIntf, CE_Settings, CE_Utils,
  // Tnt Controls
  TntStdCtrls, TntSysUtils,
  // TB2K, TBX, SpTBX
  SpTBXEditors, SpTBXFormPopupMenu, SpTBXItem, SpTBXSkins, TB2Item,
  // VSTools
  MPShellUtilities, MPCommonObjects, MPCommonUtilities,
  // System Units
  Classes, SysUtils, Windows, Messages, Graphics, ExtCtrls, Controls,
  StdCtrls, Forms, Buttons, ImgList, ShlObj, Math;

type
  TSpTBXCustomItemHack = class(TSpTBXCustomItem);

  TCE_AMemo = class(TTntMemo)
  private
    fOnValueChange: TNotifyEvent;
    procedure CNCommand(var Message: TWMCommand); message CN_COMMAND;
    procedure WMSetFocus(var Message: TWMSetFocus); message WM_SETFOCUS;
  protected
    procedure KeyPress(var Key: Char); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure AdjustSize; override;
  published
    property OnValueChange: TNotifyEvent read fOnValueChange write fOnValueChange;
  end;

  TCE_AIcon = class(TCustomControl)  
  private
    fIconIndex: Integer;
    procedure SetIconIndex(const Value: Integer);
  public
    procedure Paint; override;
    property IconIndex: Integer read fIconIndex write SetIconIndex;
  end;

  TCE_AButton = class(TSpeedButton)
  private
    fChecked: Boolean;
    fDropDownArrow: Boolean;
    fImageIndex: Integer;
    fImageList: TImageList;
    procedure SetChecked(const Value: Boolean);
  public
    procedure Paint; override;
    property Checked: Boolean read fChecked write SetChecked;
    property DropDownArrow: Boolean read fDropDownArrow write fDropDownArrow;
    property ImageIndex: Integer read fImageIndex write fImageIndex;
    property ImageList: TImageList read fImageList write fImageList;
  end;

  TCE_AFormPopupMenu = class(TSpTBXFormPopupMenu)
  private
    fPopupFormHeight: Integer;
    fPopupFormWidth: Integer;
  protected
    function InternalPopup(X, Y: Integer; ForceFocus: Boolean; PopupControl:
        TControl = nil): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    property PopupFormHeight: Integer read fPopupFormHeight write fPopupFormHeight;
    property PopupFormWidth: Integer read fPopupFormWidth write fPopupFormWidth;
  end;

  TCEAddressBar = class(TCustomPanel, ICEPathChangeHandler)
  private
    fBreadcrumbNavigation: Boolean;
    procedure SetBreadcrumbNavigation(const Value: Boolean);
    procedure SpThemeChange(var Message: TMessage); message WM_SPSKINCHANGE;
  protected
    FolderForm: TCE_FolderTreeForm;
    RootNamespace: TNamespace;
    procedure DoValueChanged(Sender: TObject);
    procedure GlobalActivePageChange(OldPage, NewPage: TComponent); virtual;
        stdcall;
    procedure GlobalContentChange(Sender: TObject); virtual; stdcall;
    procedure GlobalFocusChanged(Sender: TObject; NewPath: WideString); stdcall;
    procedure GlobalPathChanged(Sender: TObject; NewPath: WideString); stdcall;
    procedure GlobalPIDLChanged(Sender: TObject; NewPIDL: PItemIDList); stdcall;
    procedure SetParent(AParent: TWinControl); override;
  public
    TextEditor: TCE_AMemo;
    Icon: TCE_AIcon;
    DropButton: TCE_AButton;
    BreadToggleButton: TCE_AButton;
    Breadcrumb: TCEBreadcrumb;
    FolderPopupMenu: TCE_AFormPopupMenu;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure BrowseTo(APIDL: PItemIDList);
    procedure Initialize;
    procedure OnBreadToggleClick(Sender: TObject);
    procedure OnDropClick(Sender: TObject);
    procedure OnPopup(Sender: TObject);
    procedure OnTextKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Paint; override;
    property BreadcrumbNavigation: Boolean read fBreadcrumbNavigation write
        SetBreadcrumbNavigation;
  end;

type
  TCEAddressBarToolbar = class(TSpTBXToolWindow, ICESettingsHandler)
  protected
    procedure LoadFromStorage(Storage: ICESettingsStorage); stdcall;
    procedure SaveToStorage(Storage: ICESettingsStorage); stdcall;
  public
    AddressBar: TCEAddressBar;
    constructor Create(AOwner: TComponent); override;
  end;



implementation

uses
  dCE_Images;

{##############################################################################}

{*------------------------------------------------------------------------------
  Create an instance of TCE_AMemo
-------------------------------------------------------------------------------}
constructor TCE_AMemo.Create(AOwner: TComponent);
begin
  inherited;
  Self.Margins.Left:= 0;
  Self.Margins.Top:= 0;
  Self.Margins.Bottom:= 0;
  Self.AlignWithMargins:= true;
end;

{*------------------------------------------------------------------------------
  Adjust Editor rect Size
-------------------------------------------------------------------------------}
procedure TCE_AMemo.AdjustSize;
var
  XRect: TRect;
  h: Integer;
  b: TBitmap;
begin
  if not Self.HasParent then
  Exit;
  b:= TBitmap.Create;
  try
    b.Canvas.Font.Assign(Font);
    h:= b.Canvas.TextHeight('Jj');
  finally
    b.Free;
  end;
  XRect:= ClientRect;
  XRect.Top:= Round((ClientHeight-h) / 2);
  XRect.Bottom:= XRect.Top + h;
  SendMessage(Handle, EM_SETRECT, 0, integer(@XRect));
end;

{*------------------------------------------------------------------------------
  CNCommand
-------------------------------------------------------------------------------}
procedure TCE_AMemo.CNCommand(var Message: TWMCommand);
begin
  inherited;  
  if Message.NotifyCode = EN_SETFOCUS then
  AdjustSize;  
end;

{*------------------------------------------------------------------------------
  Handle Key Press
-------------------------------------------------------------------------------}
procedure TCE_AMemo.KeyPress(var Key: Char);
begin
  if (Key = Char(VK_RETURN)) then
  begin
    Key:= #0;
    if assigned(fOnValueChange) then
    fOnValueChange(Self);
  end
  else if Ord(Key) = 1 then
  begin
    Key:= #0;
    SelectAll;
  end
  else
  inherited KeyPress(Key);
end;

{*------------------------------------------------------------------------------
  Handle WMSetFocus message
-------------------------------------------------------------------------------}
procedure TCE_AMemo.WMSetFocus(var Message: TWMSetFocus);
begin
  inherited;
  self.SelectAll;
end;

{##############################################################################}

{*------------------------------------------------------------------------------
  Paint Icon
-------------------------------------------------------------------------------}
procedure TCE_AIcon.Paint;
var
  r: TRect;
  x,y: Integer;
begin
  r:= BoundsRect;
  x:= 2;
  y:= Round((r.Bottom - r.Top - 16) / 2);
  Canvas.Brush.Color:= Color;
  Canvas.FillRect(Canvas.ClipRect);
  if fIconIndex < 0 then
  Exit;  
  SmallSysImages.Draw(Canvas,x,y,fIconIndex);
end;

{*------------------------------------------------------------------------------
  Set Icon Index
-------------------------------------------------------------------------------}
procedure TCE_AIcon.SetIconIndex(const Value: Integer);
begin
  fIconIndex:= Value;
  Paint;
end;

{##############################################################################}

{*------------------------------------------------------------------------------
  Paint Button
-------------------------------------------------------------------------------}
procedure TCE_AButton.Paint;
var
  r: TRect;
  x,y,s: Integer;
begin
  r:= ClientRect;
  CurrentSkin.PaintBackground(Canvas, r, skncDock, sknsNormal, True, false);
  CurrentSkin.PaintBackground(Canvas, r, skncToolbar, sknsNormal, True, False);
  if (FState in [bsDown, bsExclusive]) or fChecked then
  begin
    SpDrawXPButton(Canvas, r, true, true, true, false, false, false, SkinManager.GetSkinType);
  end
  else
  begin
    SpDrawXPButton(Canvas, r, true, false, false, false, false, false, SkinManager.GetSkinType);
  end;
  if fDropDownArrow then
  begin
    s:= 3;
    x:= r.Left +  Round(ClientWidth / 2);
    y:= Round((ClientHeight-s) / 2);
    SpDrawArrow(Canvas, x,y, clBlack, true, false, 3);
  end
  else if assigned(fImageList) and (fImageIndex > -1) then
  begin
    x:= Round((ClientWidth - fImageList.Width) / 2);
    y:= Round((ClientHeight - fImageList.Height) / 2);
    fImageList.Draw(Canvas, x, y, fImageIndex, true);
  end;
end;

{*------------------------------------------------------------------------------
  Set Checked
-------------------------------------------------------------------------------}
procedure TCE_AButton.SetChecked(const Value: Boolean);
begin
  fChecked:= Value;
  Paint;
end;

{##############################################################################}

{*------------------------------------------------------------------------------
  Create an instance of TCE_AFormPopupMenu
-------------------------------------------------------------------------------}
constructor TCE_AFormPopupMenu.Create(AOwner: TComponent);
begin
  inherited;
  fPopupFormWidth:= 200;
  fPopupFormHeight:= 200;
end;

{*------------------------------------------------------------------------------
  Handle Popup
-------------------------------------------------------------------------------}
function TCE_AFormPopupMenu.InternalPopup(X, Y: Integer; ForceFocus: Boolean;
    PopupControl: TControl = nil): Boolean;
begin
  Result:= False;
  //ClickedItem := nil;
  SetPopupPoint(Point(X, Y));
  if Assigned(FPopupForm) then
  begin
    FPopupForm.Parent:= FWrapperForm;
    FPopupForm.Align:= alClient;
    FPopupForm.BorderStyle:= bsNone;
    FPopupForm.Visible:= True;
    //FPopupForm.Color:= CurrentTheme.GetViewColor(PVT_POPUPMENU);
    fPopupFormHeight:= FPopupForm.Height;
    if Assigned(OnPopup) then OnPopup(Self);
    if Assigned(PopupControl) then
      FWrapperForm.RollDown(PopupControl, fPopupFormWidth, fPopupFormHeight, False, PopupFocus)
    else
      FWrapperForm.RollDown(X, Y, fPopupFormWidth, fPopupFormHeight, PopupFocus);

    Result:= True;  
  end;
end;

{##############################################################################}

{*------------------------------------------------------------------------------
  Create an instance of TCEAddressBar
-------------------------------------------------------------------------------}
constructor TCEAddressBar.Create(AOwner: TComponent);
begin
  inherited;
  self.BorderWidth:= 1;
  TextEditor:= TCE_AMemo.Create(nil);
  Icon:= TCE_AIcon.Create(nil);
  Icon.Color:= clWindow;
  DropButton:= TCE_AButton.Create(nil);
  BreadToggleButton:= TCE_AButton.Create(nil);
  Breadcrumb:= TCEBreadcrumb.Create(nil);

  FolderForm:= TCE_FolderTreeForm.Create(self);
  FolderForm.CloseOnChange:= true;
  FolderForm.ChangeGlobalPathOnChange:= true;

  FolderPopupMenu:= TCE_AFormPopupMenu.Create(nil);
  FolderPopupMenu.OnPopup:= OnPopup;
  FolderPopupMenu.BorderStyle:= pbsSizeableRightBottom;
  FolderPopupMenu.PopupFocus:= true;
  FolderPopupMenu.PopupForm:= FolderForm;
  SkinManager.AddSkinNotification(Self);

  RootNamespace:= TNamespace.Create(nil,nil);
  GlobalPathCtrl.RegisterNotify(self);  
end;

{*------------------------------------------------------------------------------
  Destroy TCEAddressBar instance
-------------------------------------------------------------------------------}
destructor TCEAddressBar.Destroy;
begin
  if assigned(RootNamespace) then
  FreeAndNil(RootNamespace);
  
  SkinManager.RemoveSkinNotification(Self);
  FolderPopupMenu.Free;
  Breadcrumb.Free;
  DropButton.Free;
  BreadToggleButton.Free;
  Icon.Free;
  TextEditor.Free;
  inherited;
end;

{*------------------------------------------------------------------------------
  Initialize child objects
-------------------------------------------------------------------------------}
procedure TCEAddressBar.Initialize;
begin
  TextEditor.Parent:= self;
  TextEditor.Align:= alClient;
  TextEditor.WordWrap:= false;
  TextEditor.BorderStyle:= bsNone;
  TextEditor.OnValueChange:= DoValueChanged;
  TextEditor.OnKeyDown:= OnTextKeyDown;

  Icon.Parent:= self;
  Icon.Align:= alLeft;
  Icon.Width:= 20;
  Icon.Color:= TextEditor.Color;

  BreadToggleButton.Parent:= self;
  BreadToggleButton.Align:= alRight;
  BreadToggleButton.Color:= TextEditor.Color;
  BreadToggleButton.OnClick:= OnBreadToggleClick;

  DropButton.Parent:= self;
  DropButton.Align:= alRight;
  DropButton.Color:= TextEditor.Color;
  DropButton.DropDownArrow:= true;
  DropButton.Left:= BreadToggleButton.BoundsRect.Right;
  DropButton.OnClick:= OnDropClick;

  Breadcrumb.Parent:= self;
  Breadcrumb.Align:= alClient;
  Breadcrumb.Visible:= false;
  Breadcrumb.ShowBorder:= false;
  Breadcrumb.SeparatorSize:= 1;
end;

{*------------------------------------------------------------------------------
  Set Parent
-------------------------------------------------------------------------------}
procedure TCEAddressBar.SetParent(AParent: TWinControl);
begin
  inherited;
  if AParent <> nil then
  Initialize;
end;

{*------------------------------------------------------------------------------
  Paint
-------------------------------------------------------------------------------}
procedure TCEAddressBar.Paint;
var
  r: TRect;
begin
  inherited;
  Canvas.Brush.Color:= clWindow;
  r:= BoundsRect;
  Canvas.FillRect(r);
  SpDrawXPEditFrame(Canvas,r,true,true,SkinManager.GetSkinType);
end;

{*------------------------------------------------------------------------------
  Change RootNamespace
-------------------------------------------------------------------------------}
procedure TCEAddressBar.BrowseTo(APIDL: PItemIDList);
begin
  if assigned(RootNamespace) then
  FreeAndNil(RootNamespace);

  if not TextEditor.Focused then
  TextEditor.AdjustSize;

  RootNamespace:= TNamespace.Create(PIDLMgr.CopyPIDL(APIDL),nil);
  TextEditor.Text:= RootNamespace.NameParseAddress;
  Icon.IconIndex:= RootNamespace.GetIconIndex(false, icSmall);
end;

{*------------------------------------------------------------------------------
  Change Value
-------------------------------------------------------------------------------}
procedure TCEAddressBar.DoValueChanged(Sender: TObject);
var
  ws: WideString;
  error: WideString;
  PIDL: PItemIDList;
  errCode: Cardinal;
begin
  ws:= WideIncludeTrailingBackslash(TextEditor.Text);
  if ws = '' then
  Exit;

  if IsUNC(ws) then
  begin
    ws:= WideExcludeTrailingBackslash(ws);
    errCode:= UseConnection(ws, Application.MainFormHandle);
    if errCode <> NO_ERROR then
    begin
      if errCode <> ERROR_CANCELLED then
      begin
        error:= WideSysErrorMessage(GetLastError);
        WideMessageBox(Application.MainFormHandle, 'Connection error!', error, MB_ICONERROR or MB_OK);
      end;
      exit;
    end;
  end;

  PIDL:= PathToPIDL(ws);

  if assigned(PIDL) then
  begin
    if assigned(RootNamespace) then
    FreeAndNil(RootNamespace);

    RootNamespace:= TNamespace.Create(PIDL, nil);
    TextEditor.Text:= RootNamespace.NameParseAddress;
    TextEditor.SetSelStart(Length(TextEditor.Text));
    Icon.IconIndex:= RootNamespace.GetIconIndex(false, icSmall);
    GlobalPathCtrl.ChangeGlobalPathPIDL(Self, RootNamespace.AbsolutePIDL);
  end;
end;

{*------------------------------------------------------------------------------
  Get's called when Active page has changed
-------------------------------------------------------------------------------}
procedure TCEAddressBar.GlobalActivePageChange(OldPage, NewPage: TComponent);
begin
  // Override from descendant
end;

{*------------------------------------------------------------------------------
  Get's called when global content has changed
-------------------------------------------------------------------------------}
procedure TCEAddressBar.GlobalContentChange(Sender: TObject);
begin
  // Override from descendant
end;

{*------------------------------------------------------------------------------
  Get's called on global focus change.
-------------------------------------------------------------------------------}
procedure TCEAddressBar.GlobalFocusChanged(Sender: TObject; NewPath:
    WideString);
begin
  // Do nothing
end;

{*------------------------------------------------------------------------------
  Get's called on global path change (string)
-------------------------------------------------------------------------------}
procedure TCEAddressBar.GlobalPathChanged(Sender: TObject; NewPath: WideString);
var
  apidl: PItemIDList;
begin
  apidl:= PathToPIDL(NewPath);
  try
    GlobalPIDLChanged(Sender, apidl);
  finally
    if assigned(apidl) then
    PIDLMgr.FreeAndNilPIDL(apidl);
  end;
end;

{*------------------------------------------------------------------------------
  Get's called on global path change (PIDL)
-------------------------------------------------------------------------------}
procedure TCEAddressBar.GlobalPIDLChanged(Sender: TObject; NewPIDL:
    PItemIDList);
begin
  BrowseTo(NewPIDL);
end;

{*------------------------------------------------------------------------------
  On BreadToggleButton Click
-------------------------------------------------------------------------------}
procedure TCEAddressBar.OnBreadToggleClick(Sender: TObject);
begin
  BreadcrumbNavigation:= not BreadcrumbNavigation;
end;

{*------------------------------------------------------------------------------
  On Popup
-------------------------------------------------------------------------------}
procedure TCEAddressBar.OnPopup(Sender: TObject);
begin
  if assigned(RootNamespace) then
  FolderForm.FolderTree.BrowseToByPIDL(RootNamespace.AbsolutePIDL, true, true, false, true);
end;

{*------------------------------------------------------------------------------
  On DropButton Click
-------------------------------------------------------------------------------}
procedure TCEAddressBar.OnDropClick(Sender: TObject);
var
  p: TPoint;
begin
  FolderPopupMenu.PopupFormWidth:= Self.Width;
  p.X:= 0;
  p.Y:= Self.Height;
  p:= Self.ClientToScreen(p);
  FolderPopupMenu.Popup(p.X, p.Y);
end;

{*------------------------------------------------------------------------------
  On TextEditor Key Down
-------------------------------------------------------------------------------}
procedure TCEAddressBar.OnTextKeyDown(Sender: TObject; var Key: Word; Shift:
    TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    if assigned(RootNamespace) then
    TextEditor.Text:= RootNamespace.NameParseAddress;
    TextEditor.SetSelStart(Length(TextEditor.Text));
  end;
end;

{*------------------------------------------------------------------------------
  Set BreadcrumbNavigation
-------------------------------------------------------------------------------}
procedure TCEAddressBar.SetBreadcrumbNavigation(const Value: Boolean);
begin
  fBreadcrumbNavigation:= Value;
  if fBreadcrumbNavigation then
  begin
    Breadcrumb.Visible:= true;
    TextEditor.Visible:= false;
    Icon.Visible:= false;
    BreadToggleButton.Checked:= true;
  end
  else
  begin
    TextEditor.Visible:= true;
    Icon.Visible:= true;
    Breadcrumb.Visible:= false;
    BreadToggleButton.Checked:= false;
  end;
end;

{*------------------------------------------------------------------------------
  Get's called on TBX theme change
-------------------------------------------------------------------------------}
procedure TCEAddressBar.SpThemeChange(var Message: TMessage);
begin
  Paint;
  Icon.Paint;
  TextEditor.AdjustSize;
  DropButton.Paint;
  BreadToggleButton.Paint;
end;

{##############################################################################}

{*------------------------------------------------------------------------------
  Create instance of TCEAddressBarToolbar
-------------------------------------------------------------------------------}
constructor TCEAddressBarToolbar.Create(AOwner: TComponent);
begin
  inherited;
  SetDesktopIconFonts(Font);
  Parent:= TWinControl(AOwner);
  Self.MinClientWidth:= 50;
  self.Stretch:= true;
  AddressBar:= TCEAddressBar.Create(self);
  AddressBar.Parent:= self;
  AddressBar.Align:= alClient;
  AddressBar.BreadToggleButton.ImageList:= CE_Images.MiscImages;
  AddressBar.BreadToggleButton.ImageIndex:= 0;
  self.MinClientHeight:= Max(AddressBar.Breadcrumb.Constraints.MinHeight,20);
  self.ClientHeight:= 22;
  GlobalSettings.RegisterHandler(Self);
end;

{-------------------------------------------------------------------------------
  Load From Storage
-------------------------------------------------------------------------------}
procedure TCEAddressBarToolbar.LoadFromStorage(Storage: ICESettingsStorage);
begin
  Storage.OpenPath('/AddressBar');
  try
    // Toggles
    AddressBar.BreadcrumbNavigation:= Storage.ReadBoolean('Breadcrumb',false);
  finally
    Storage.ClosePath;
  end;
end;

{-------------------------------------------------------------------------------
  Save to storage
-------------------------------------------------------------------------------}
procedure TCEAddressBarToolbar.SaveToStorage(Storage: ICESettingsStorage);
begin
  Storage.OpenPath('/AddressBar');
  try
    // Toggles
    Storage.WriteBoolean('Breadcrumb',  AddressBar.BreadcrumbNavigation);
  finally
    Storage.ClosePath;
  end;
end;


end.