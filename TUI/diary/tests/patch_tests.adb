with Ada.Characters.Latin_1;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Diary_Tooling_Patches;

procedure Patch_Tests is
   use Ada.Characters.Latin_1;
   use Ada.Strings.Fixed;
   use Diary_Tooling_Patches;

   Failures : Natural := 0;
   CRLF     : constant String := CR & LF;

   procedure Expect (Condition : Boolean; Description : String) is
   begin
      if not Condition then
         Ada.Text_IO.Put_Line ("FAIL " & Description);
         Failures := Failures + 1;
      end if;
   end Expect;

   procedure Check
     (Name, Source, Expected, Description : String;
      Platform                            : String := "linux")
   is
      Actual : constant String := Transform (Name, Source, Platform);
   begin
      Expect (Actual = Expected, Description);
      Expect
        (Transform (Name, Actual, Platform) = Actual,
         Description & " is idempotent");
   end Check;

   procedure Check_Image_Aspects is
      Declaration : constant String :=
        "   type Style is tagged private with" & LF;
      Aspect      : constant String :=
        HT & "Put_Image       => Put_Image," & LF;
      Rest        : constant String :=
        "      Global => null;" & LF & "   procedure Put_Image;" & LF;
   begin
      Check
        ("drawing/malef-groups.ads",
         Declaration & Aspect & Rest,
         Declaration & LF & Rest,
         "groups Put_Image aspect removed");
      Check
        ("widgets/malef-styles.ads",
         Declaration & Aspect & Rest,
         Declaration & LF & Rest,
         "styles Put_Image aspect removed");
      Check
        ("widgets/malef-styles-classes.ads",
         Declaration & Aspect & Rest,
         Declaration & LF & Rest,
         "classes Put_Image aspect removed");
      Check
        ("widgets/malef-styles-sheets.ads",
         Declaration & Aspect & Rest,
         Declaration & LF & Rest,
         "sheets Put_Image aspect removed");
      Check
        ("drawing/malef-surfaces.ads",
         Declaration & Aspect & Rest,
         Declaration & Aspect & Rest,
         "surfaces Put_Image aspect preserved");
      Check
        ("widgets/malef-styles.ads",
         "   type Style is tagged private with"
         & CRLF
         & "      Put_Image       => Put_Image,"
         & CRLF
         & "      Global => null;"
         & CRLF,
         Declaration & LF & "      Global => null;" & LF,
         "Put_Image aspect removed from CRLF source");
      Check
        ("widgets/malef-styles.ads",
         "   type Style is tagged private with"
         & CRLF
         & "      Global => null;"
         & CRLF,
         "   type Style is tagged private with"
         & CRLF
         & "      Global => null;"
         & CRLF,
         "unchanged known source retains CRLF endings");
      Check
        ("drawing/malef-surfaces.ads",
         "      Put_Image       => Put_Image," & CRLF,
         "      Put_Image       => Put_Image," & CRLF,
         "unrecognized source retains CRLF endings");
   end Check_Image_Aspects;

   procedure Check_Groups is
      Declaration    : constant String :=
        "   function Last_Index ("
        & LF
        & "      Object : in Group)"
        & LF
        & "      return Layer_Count";
      Expression     : constant String :=
        " is ("
        & LF
        & "      [for I in 1 .. Object.Capacity =>"
        & LF
        & "         (if Contains (Object, I) then I else 0)]'"
        & LF
        & "         Reduce (Layer_Count'Max, 0));";
      Header         : constant String := "package body Malef.Groups is";
      Footer         : constant String := LF & LF & "end Malef.Groups;" & LF;
      Implementation : constant String :=
        LF
        & "   function Last_Index (Object : in Group) return Layer_Count is"
        & LF
        & "   begin"
        & LF
        & "      for Index in reverse 1 .. Object.Capacity loop"
        & LF
        & "         if Contains (Object, Index) then"
        & LF
        & "            return Index;"
        & LF
        & "         end if;"
        & LF
        & "      end loop;"
        & LF
        & "      return 0;"
        & LF
        & "   end Last_Index;";
   begin
      Check
        ("drawing/malef-groups.ads",
         Declaration & Expression & Footer,
         Declaration & ";" & Footer,
         "Last_Index specification forward-declared");
      Check
        ("drawing/malef-groups.ads",
         Declaration & " is (0);",
         Declaration & " is (0);",
         "unrelated Last_Index expression preserved");
      Check
        ("drawing/malef-groups.adb",
         Header & Footer,
         Header & Implementation & Footer,
         "Last_Index implementation inserted");
      Check
        ("drawing/malef-groups.adb",
         Footer,
         Footer,
         "Last_Index insertion requires a package body header");
      Check
        ("drawing/malef-groups.ads",
         "   function Last_Index ("
         & CRLF
         & "      Object : in Group)"
         & CRLF
         & "      return Layer_Count is ("
         & CRLF
         & "      [for I in 1 .. Object.Capacity =>"
         & CRLF
         & "         (if Contains (Object, I) then I else 0)]'"
         & CRLF
         & "         Reduce (Layer_Count'Max, 0));"
         & CRLF
         & CRLF
         & "end Malef.Groups;"
         & CRLF,
         Declaration & ";" & Footer,
         "CRLF Last_Index specification forward-declared");
      Check
        ("drawing/malef-groups.adb",
         Header & CRLF & CRLF & "end Malef.Groups;" & CRLF,
         Header & Implementation & Footer,
         "CRLF Last_Index implementation inserted with consistent line endings");
   end Check_Groups;

   procedure Check_Window_Observers is
   begin
      Check
        ("drawing/malef-window.adb",
         "Implementation.Observer_Info'(Observer, Callback);"
         & LF
         & "Implementation.Observer_Info'(Observer, null);"
         & LF,
         "Implementation.Observer_Info'(Implementation.Observer_Access (Observer), Callback);"
         & LF
         & "Implementation.Observer_Info'(Implementation.Observer_Access (Observer), null);"
         & LF,
         "registration and removal convert observer access");
   end Check_Window_Observers;

   procedure Check_Palette_Distance is
      Header   : constant String :=
        "   function Distance (Left, Right : in RGBA_Type)" & LF;
      Expected : constant String :=
        Header
        & "      return Integer is"
        & LF
        & "      Result : Integer := 0;"
        & LF
        & "   begin"
        & LF
        & "      for Component in Component_Name loop"
        & LF
        & "         Result := Result + (Integer (Left (Component)) - Integer (Right (Component))) ** 2;"
        & LF
        & "      end loop;"
        & LF
        & "      return Result;"
        & LF
        & "   end Distance;";
   begin
      Check
        ("drawing/malef-palettes.adb",
         Header
         & "      return Integer is ("
         & LF
         & "      [for I in Component_Name'Range =>"
         & LF
         & "         (Integer (Left (I)) - Integer (Right (I))) ** 2]'Reduce (""+"", 0));",
         Expected,
         "palette distance accumulates squared component differences");
      Check
        ("drawing/malef-palettes.adb",
         "   function Distance (Left, Right : in RGBA_Type)"
         & CRLF
         & "      return Integer is ("
         & CRLF
         & "      [for I in Component_Name'Range =>"
         & CRLF
         & "         (Integer (Left (I)) - Integer (Right (I))) ** 2]'Reduce (""+"", 0));"
         & CRLF,
         Expected & LF,
         "CRLF palette distance expression becomes an ordinary function body");
   end Check_Palette_Distance;

   procedure Check_Composers is
      Name      : constant String := "private/malef-groups-composers.adb";
      Unchanged : constant String :=
        "Malef.Alpha W.Alpha Other . Alpha Other.Component_Type"
        & LF
        & "PreAlpha Alpha_2 Component_Type_2 Other_Component_Type"
        & LF
        & "-- Alpha and Component_Type"
        & LF
        & "Value := ""Alpha """" Component_Type"";"
        & LF;
      Header    : constant String :=
        "   function Simple_Addition (Top, Bottom : in RGBA_Type)" & LF;
      Original  : constant String :=
        Header
        & "      return RGBA_Type is ("
        & LF
        & "      (if    Top (Alpha) = 255 then Top"
        & LF
        & "       elsif Top (Alpha) = 0   then Bottom"
        & LF
        & "       else (declare"
        & LF
        & "         W : constant Weights := Weight (Top, Bottom);"
        & LF
        & "       begin"
        & LF
        & "          [for I in Top'Range =>"
        & LF
        & "             (if I = Alpha then W.Alpha"
        & LF
        & "               else Component_Type (Add (Float (Top (I)) * W.Top,"
        & LF
        & "                                         Float (Bottom (I)) * W.Bottom)))])"
        & LF
        & "      ));"
        & LF;
      Actual    : constant String := Transform (Name, Original, "linux");
   begin
      Check
        (Name,
         Unchanged & "Alpha Component_Type'Last (Alpha)",
         Unchanged & "Malef.Alpha Malef.Component_Type'Last (Malef.Alpha)",
         "composer qualification respects identifier boundaries");
      Expect
        (Index
           (Actual,
            "if Top (Malef.Alpha) = 255 then" & LF & "         return Top;")
         /= 0,
         "opaque top layer short-circuits composition");
      Expect
        (Index
           (Actual,
            "elsif Top (Malef.Alpha) = 0 then"
            & LF
            & "         return Bottom;")
         /= 0,
         "transparent top layer short-circuits composition");
      Expect
        (Index (Actual, "Result (Component) := W.Alpha;") /= 0,
         "combined alpha comes from the weights");
      Expect
        (Index
           (Actual,
            "Add (Float (Top (Component)) * W.Top, Float (Bottom (Component)) * W.Bottom)")
         /= 0,
         "color components combine weighted layers");
      Expect
        (Index (Actual, "return Result;" & LF & "   end Simple_Addition;" & LF)
         /= 0,
         "composer is an ordinary function body");
      Expect
        (Transform (Name, Actual, "linux") = Actual,
         "composer replacement is idempotent");
   end Check_Composers;

   procedure Check_Termios is
      Name         : constant String :=
        "subsystems/ansi/posix/__malef-platform-terminal-input-implementation.c";
      Canonical    : constant String :=
        "  new_term.c_lflag &= ~ICANON & ~ECHO;" & LF;
      Flow_Control : constant String :=
        "  new_term.c_iflag &= ~(IXON | ICRNL);" & LF;
      Extended     : constant String := "  new_term.c_lflag &= ~IEXTEN;" & LF;
   begin
      Check
        (Name,
         Canonical,
         Canonical & Flow_Control & Extended,
         "termios allows raw control keys and carriage return");
      Check
        (Name,
         Canonical & Flow_Control,
         Canonical & Flow_Control & Extended,
         "termios completes a partially patched source");
      Check
        (Name,
         "  new_term.c_lflag &= ~ICANON & ~ECHO;" & CR & "  return;" & CR,
         Canonical & Flow_Control & Extended & "  return;" & LF,
         "termios flags use LF after rewriting a source with lone CR endings");
   end Check_Termios;

   procedure Check_Byte_Reading is
      Name     : constant String :=
        "subsystems/ansi/posix/malef-platform-terminal-input-get_byte_immediate.adb";
      Original : constant String :=
        "      STDIN_FILENO : constant := 1;"
        & LF
        & "         External_Name => ""stdin"";"
        & LF
        & "      elsif Buffer = EOF_Ch then"
        & LF
        & "         raise End_Error;"
        & LF;
      Linux    : constant String :=
        "      STDIN_FILENO : constant := 0;"
        & LF
        & "         External_Name => ""stdin"";"
        & LF
        & "      elsif False and then Buffer = EOF_Ch then"
        & LF
        & "         raise End_Error;"
        & LF;
      Mac      : constant String :=
        "      STDIN_FILENO : constant := 0;"
        & LF
        & "         External_Name => ""__stdinp"";"
        & LF
        & "      elsif False and then Buffer = EOF_Ch then"
        & LF
        & "         raise End_Error;"
        & LF;
   begin
      Check
        (Name,
         Original,
         Linux,
         "Linux reads from stdin fd 0 and accepts the EOF control byte");
      Check (Name, Original, Mac, "macOS imports __stdinp", "macos");
      Check
        (Name,
         Mac,
         Linux,
         "Linux restores the stdin import after a macOS patch");
   end Check_Byte_Reading;

   procedure Check_Terminal_Input is
      Name                 : constant String :=
        "subsystems/ansi/malef-platform-terminal-input.adb";
      Ioctl                : constant String :=
        "   TIOCGWINSZ : constant Interfaces.C.unsigned_long := 16#";
      Nul_Key              : constant String :=
        "            if Key = Key_Type'Val (0) then"
        & LF
        & "               Key := Key_Unknown;"
        & LF
        & "            elsif Key = Key_Type'Val (27) then"
        & LF;
      Escape_Key           : constant String :=
        "            if Key = Key_Type'Val (27) then" & LF;
      Unchecked_Dimensions : constant String :=
        "      Rows := Row_Type (ws.ws_row);"
        & LF
        & "      Cols := Col_Type (ws.ws_col);"
        & LF;
      Guarded_Dimensions   : constant String :=
        "      if Integer (temp) = 0"
        & LF
        & "         and then Natural (ws.ws_row) in 1 .. Natural (Row_Type'Last)"
        & LF
        & "         and then Natural (ws.ws_col) in 1 .. Natural (Col_Type'Last)"
        & LF
        & "      then"
        & LF
        & "         Rows := Row_Type (ws.ws_row);"
        & LF
        & "         Cols := Col_Type (ws.ws_col);"
        & LF
        & "      else"
        & LF
        & "         Rows := 24;"
        & LF
        & "         Cols := 80;"
        & LF
        & "      end if;"
        & LF;
      Original             : constant String :=
        Ioctl & "f00D#;" & LF & Nul_Key & Unchecked_Dimensions;
      Linux                : constant String :=
        Ioctl & "5413#;" & LF & Escape_Key & Guarded_Dimensions;
      Mac                  : constant String :=
        Ioctl & "40087468#;" & LF & Escape_Key & Guarded_Dimensions;
   begin
      Check
        (Name,
         Original,
         Linux,
         "Linux terminal ioctl, NUL key handling and guarded dimensions");
      Check
        (Name,
         Linux,
         Mac,
         "macOS replaces the Linux terminal ioctl constant",
         "macos");
      Check
        (Name,
         Mac,
         Linux,
         "Linux restores its terminal ioctl constant after a macOS patch");
      Check
        (Name,
         Ioctl & "malformed#;",
         Ioctl & "malformed#;",
         "malformed ioctl constant is untouched");
      Check
        (Name,
         Ioctl
         & "5413#;"
         & CRLF
         & "            if Key = Key_Type'Val (0) then"
         & CRLF
         & "               Key := Key_Unknown;"
         & CRLF
         & "            elsif Key = Key_Type'Val (27) then"
         & CRLF
         & "      Rows := Row_Type (ws.ws_row);"
         & CRLF
         & "      Cols := Col_Type (ws.ws_col);"
         & CRLF,
         Mac,
         "CRLF terminal input accepts NUL and guards dimensions on macOS",
         "macos");
   end Check_Terminal_Input;
begin
   Check_Image_Aspects;
   Check_Groups;
   Check_Window_Observers;
   Check_Palette_Distance;
   Check_Composers;
   Check_Termios;
   Check_Byte_Reading;
   Check_Terminal_Input;
   Check
     ("private/malef-groups-composers.adb",
      "",
      "",
      "empty source is unchanged");

   if Failures /= 0 then
      raise Program_Error with "Malef patch test failures:" & Failures'Image;
   end if;
   Ada.Text_IO.Put_Line
     ("PASS Malef source transformations on Linux and macOS");
end Patch_Tests;
