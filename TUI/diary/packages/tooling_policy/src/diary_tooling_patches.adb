with Ada.Characters.Latin_1;
with Ada.Strings.Fixed;
with Ada.Strings.Maps;
with Ada.Strings.Unbounded;

package body Diary_Tooling_Patches is
   use Ada.Characters.Latin_1;
   use Ada.Strings.Fixed;
   use Ada.Strings.Unbounded;

   Whitespace : constant Ada.Strings.Maps.Character_Set :=
     Ada.Strings.Maps.To_Set (" " & HT & LF & VT & FF & CR);

   function Replace (Source, Pattern, Replacement : String) return String is
      Result : Unbounded_String;
      First  : Positive := Source'First;
      Match  : Natural;
   begin
      while First <= Source'Last loop
         Match := Index (Source, Pattern, From => First);
         exit when Match = 0;
         Append (Result, Source (First .. Match - 1));
         Append (Result, Replacement);
         First := Match + Pattern'Length;
      end loop;
      return To_String (Result) & Source (First .. Source'Last);
   end Replace;

   function Replace_Span
     (Source, Opening, Closing, Replacement : String) return String
   is
      First : constant Natural := Index (Source, Opening);
      Last  : Natural;
   begin
      if First = 0 or else First + Opening'Length > Source'Last then
         return Source;
      end if;
      Last := Index (Source, Closing, From => First + Opening'Length);
      if Last = 0 then
         return Source;
      end if;
      return
        Replace_Slice (Source, First, Last + Closing'Length - 1, Replacement);
   end Replace_Span;

   function Is_Image_Aspect (Line : String) return Boolean is
      Arrow : constant Natural := Index (Line, "=>");
   begin
      return
        Arrow /= 0
        and then Trim (Line (Line'First .. Arrow - 1), Whitespace, Whitespace)
                 = "Put_Image"
        and then Line (Arrow + 2 .. Line'Last) = " Put_Image,";
   end Is_Image_Aspect;

   function Without_Image_Aspects (Source : String) return String is
      Result          : Unbounded_String;
      Line_First      : Positive := Source'First;
      Aspect_First    : Positive := Source'First;
      Unchanged_First : Positive := Source'First;
      Line_End        : Natural;
   begin
      while Line_First <= Source'Last loop
         Line_End := Index (Source, [1 => LF], From => Line_First);
         exit when Line_End = 0;
         declare
            Line : constant String := Source (Line_First .. Line_End - 1);
         begin
            if Is_Image_Aspect (Line) then
               Append (Result, Source (Unchanged_First .. Aspect_First - 1));
               Append (Result, LF);
               Unchanged_First := Line_End + 1;
            end if;
            if Trim (Line, Whitespace, Whitespace) /= "" then
               Aspect_First := Line_End + 1;
            end if;
         end;
         Line_First := Line_End + 1;
      end loop;
      return To_String (Result) & Source (Unchanged_First .. Source'Last);
   end Without_Image_Aspects;

   function Patch_Groups_Specification (Source : String) return String is
      Declaration : constant String :=
        "   function Last_Index ("
        & LF
        & "      Object : in Group)"
        & LF
        & "      return Layer_Count";
   begin
      return
        Replace_Span
          (Without_Image_Aspects (Source),
           Declaration & " is (",
           "Reduce (Layer_Count'Max, 0));",
           Declaration & ";");
   end Patch_Groups_Specification;

   function Patch_Groups_Body (Source : String) return String is
      Header         : constant String := "package body Malef.Groups is";
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
      Body_Start     : constant Natural := Index (Source, Header);
   begin
      if Body_Start = 0 or else Index (Source, "function Last_Index (") /= 0
      then
         return Source;
      end if;
      return Insert (Source, Body_Start + Header'Length, Implementation);
   end Patch_Groups_Body;

   function Patch_Observers (Source : String) return String is
      Observers : constant String :=
        Replace
          (Source,
           "Observer_Info'(Observer, Callback)",
           "Observer_Info'(Implementation.Observer_Access (Observer), Callback)");
   begin
      return
        Replace
          (Observers,
           "Observer_Info'(Observer, null)",
           "Observer_Info'(Implementation.Observer_Access (Observer), null)");
   end Patch_Observers;

   function Patch_Distance (Source : String) return String is
      Expression     : constant String :=
        "      return Integer is ("
        & LF
        & "      [for I in Component_Name'Range =>"
        & LF
        & "         (Integer (Left (I)) - Integer (Right (I))) ** 2]'Reduce (""+"", 0));";
      Implementation : constant String :=
        "      return Integer is"
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
      return Replace (Source, Expression, Implementation);
   end Patch_Distance;

   function Is_Name_Character (Item : Character) return Boolean
   is (Item
       in 'A' .. 'Z'
        | 'a' .. 'z'
        | '0' .. '9'
        | '_'
        | Character'Val (128) .. Character'Last);

   function Starts_Name
     (Source : String; First : Positive; Name : String) return Boolean
   is
      Last : constant Natural := First + Name'Length - 1;
   begin
      return
        Last <= Source'Last
        and then Source (First .. Last) = Name
        and then (First = Source'First
                  or else not Is_Name_Character (Source (First - 1)))
        and then (Last = Source'Last
                  or else not Is_Name_Character (Source (Last + 1)));
   end Starts_Name;

   function Qualify_Composer_Names (Source : String) return String is
      Result          : Unbounded_String;
      Unchanged_First : Positive := Source'First;
      Previous        : Character := ' ';
      In_Comment      : Boolean := False;
      In_String       : Boolean := False;
   begin
      for Position in Source'Range loop
         declare
            Item : constant Character := Source (Position);
         begin
            if In_Comment then
               In_Comment := Item /= LF;
            elsif Item = '"' then
               if In_String
                 or else Position = Source'First
                 or else Position = Source'Last
                 or else Source (Position - 1) /= '''
                 or else Source (Position + 1) /= '''
               then
                  In_String := not In_String;
               end if;
               Previous := Item;
            elsif not In_String then
               if Item = '-'
                 and then Position < Source'Last
                 and then Source (Position + 1) = '-'
               then
                  In_Comment := True;
               elsif not Ada.Strings.Maps.Is_In (Item, Whitespace) then
                  if Previous /= '.'
                    and then (Starts_Name (Source, Position, "Alpha")
                              or else Starts_Name
                                        (Source, Position, "Component_Type"))
                  then
                     Append (Result, Source (Unchanged_First .. Position - 1));
                     Append (Result, "Malef.");
                     Unchanged_First := Position;
                  end if;
                  Previous := Item;
               end if;
            end if;
         end;
      end loop;
      return To_String (Result) & Source (Unchanged_First .. Source'Last);
   end Qualify_Composer_Names;

   function Patch_Composers (Source : String) return String is
      Declaration    : constant String :=
        "   function Simple_Addition (Top, Bottom : in RGBA_Type)"
        & LF
        & "      return RGBA_Type is";
      Implementation : constant String :=
        Declaration
        & LF
        & "      W : Weights;"
        & LF
        & "      Result : RGBA_Type;"
        & LF
        & "   begin"
        & LF
        & "      if Top (Malef.Alpha) = 255 then"
        & LF
        & "         return Top;"
        & LF
        & "      elsif Top (Malef.Alpha) = 0 then"
        & LF
        & "         return Bottom;"
        & LF
        & "      end if;"
        & LF
        & "      W := Weight (Top, Bottom);"
        & LF
        & "      for Component in Component_Name loop"
        & LF
        & "         if Component = Malef.Alpha then"
        & LF
        & "            Result (Component) := W.Alpha;"
        & LF
        & "         else"
        & LF
        & "            Result (Component) := Malef.Component_Type (Add"
        & " (Float (Top (Component)) * W.Top, Float (Bottom (Component)) * W.Bottom));"
        & LF
        & "         end if;"
        & LF
        & "      end loop;"
        & LF
        & "      return Result;"
        & LF
        & "   end Simple_Addition;";
   begin
      return
        Qualify_Composer_Names
          (Replace_Span
             (Source, Declaration & " (", LF & "      ));", Implementation));
   end Patch_Composers;

   function Patch_Resize_Signal (Source : String) return String is
      Header  : constant String :=
        "#ifdef __APPLE__"
        & LF
        & "#include <signal.h>"
        & LF
        & "static void (*diary_old_winch_handler) (int) = SIG_DFL;"
        & LF
        & "static void diary_winch_handler (int signum) { (void) signum; }"
        & LF
        & "#endif"
        & LF;
      Prepare : constant String := "void MALEF(prepare) (void) {";
      Restore : constant String := "void MALEF(restore) (void) {";
   begin
      if Index (Source, "static void diary_winch_handler") /= 0 then
         return Source;
      end if;
      return
        Replace
          (Replace
             (Replace
                (Source,
                 "#include <termios.h>",
                 Header & "#include <termios.h>"),
              Prepare,
              Prepare
              & LF
              & "#ifdef __APPLE__"
              & LF
              & "  diary_old_winch_handler = signal (SIGWINCH, diary_winch_handler);"
              & LF
              & "#endif"),
           Restore,
           Restore
           & LF
           & "#ifdef __APPLE__"
           & LF
           & "  if (diary_old_winch_handler != SIG_ERR)"
           & LF
           & "    signal (SIGWINCH, diary_old_winch_handler);"
           & LF
           & "#endif");
   end Patch_Resize_Signal;

   function Patch_Termios (Source : String) return String is
      Canonical    : constant String :=
        "  new_term.c_lflag &= ~ICANON & ~ECHO;";
      Flow_Control : constant String :=
        "  new_term.c_iflag &= ~(IXON | ICRNL);";
      Extended     : constant String := "  new_term.c_lflag &= ~IEXTEN;";
      Result       : constant String :=
        (if Index (Source, "new_term.c_iflag &= ~(IXON | ICRNL);") = 0
         then Replace (Source, Canonical, Canonical & LF & Flow_Control)
         else Source);
   begin
      if Index (Result, "new_term.c_lflag &= ~IEXTEN;") = 0 then
         return Replace (Result, Flow_Control, Flow_Control & LF & Extended);
      end if;
      return Result;
   end Patch_Termios;

   function Patch_Byte_Reading (Source, Platform : String) return String is
      Descriptor   : constant String :=
        Replace
          (Source,
           "STDIN_FILENO : constant := 1;",
           "STDIN_FILENO : constant := 0;");
      Linux_Import : constant String := "External_Name => ""stdin""";
      Mac_Import   : constant String := "External_Name => ""__stdinp""";
      Import_Name  : constant String :=
        (if Platform = "macos"
         then Replace (Descriptor, Linux_Import, Mac_Import)
         else Replace (Descriptor, Mac_Import, Linux_Import));
   begin
      return
        Replace
          (Import_Name,
           "      elsif Buffer = EOF_Ch then",
           "      elsif False and then Buffer = EOF_Ch then");
   end Patch_Byte_Reading;

   function Patch_Window_Size_Code (Source, Platform : String) return String is
      Prefix : constant String :=
        "TIOCGWINSZ : constant Interfaces.C.unsigned_long := 16#";
      Start  : constant Natural := Index (Source, Prefix);
      Code   : constant String :=
        (if Platform = "macos" then "40087468" else "5413");
      First  : constant Natural := Start + Prefix'Length;
      After  : Natural;
   begin
      if Start = 0 or else First > Source'Last then
         return Source;
      end if;
      After := Index (Source, "#;", From => First);
      if After <= First
        or else (for some Digit of Source (First .. After - 1) =>
                   Digit not in '0' .. '9' | 'A' .. 'F' | 'a' .. 'f')
      then
         return Source;
      end if;
      return Replace_Slice (Source, First, After - 1, Code);
   end Patch_Window_Size_Code;

   function Patch_Terminal_Input (Source, Platform : String) return String is
      Nul_Check          : constant String :=
        "            if Key = Key_Type'Val (0) then"
        & LF
        & "               Key := Key_Unknown;"
        & LF
        & "            elsif Key = Key_Type'Val (27) then";
      Escape_Check       : constant String :=
        "            if Key = Key_Type'Val (27) then";
      Dimensions         : constant String :=
        "      Rows := Row_Type (ws.ws_row);"
        & LF
        & "      Cols := Col_Type (ws.ws_col);";
      Guarded_Dimensions : constant String :=
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
        & "      end if;";
      Platform_Code      : constant String :=
        Patch_Window_Size_Code (Source, Platform);
      Variadic_Ioctl     : constant String :=
        Replace
          (Platform_Code,
           "      Convention    => C,"
           & LF
           & "      External_Name => ""ioctl"";",
           "      Convention    => C_Variadic_2,"
           & LF
           & "      External_Name => ""ioctl"";");
      Accepted_Nul       : constant String :=
        Replace (Variadic_Ioctl, Nul_Check, Escape_Check);
   begin
      return Replace (Accepted_Nul, Dimensions, Guarded_Dimensions);
   end Patch_Terminal_Input;

   function Patch_Source (Name, Source, Platform : String) return String is
   begin
      if Name = "drawing/malef-groups.ads" then
         return Patch_Groups_Specification (Source);
      elsif Name = "widgets/malef-styles.ads"
        or else Name = "widgets/malef-styles-classes.ads"
        or else Name = "widgets/malef-styles-sheets.ads"
      then
         return Without_Image_Aspects (Source);
      elsif Name = "drawing/malef-groups.adb" then
         return Patch_Groups_Body (Source);
      elsif Name = "drawing/malef-window.adb" then
         return Patch_Observers (Source);
      elsif Name = "drawing/malef-palettes.adb" then
         return Patch_Distance (Source);
      elsif Name = "private/malef-groups-composers.adb" then
         return Patch_Composers (Source);
      elsif Name
        = "subsystems/ansi/posix/__malef-platform-terminal-input-implementation.c"
      then
         return Patch_Resize_Signal (Patch_Termios (Source));
      elsif Name
        = "subsystems/ansi/posix/malef-platform-terminal-input-get_byte_immediate.adb"
      then
         return Patch_Byte_Reading (Source, Platform);
      elsif Name = "subsystems/ansi/malef-platform-terminal-input.adb" then
         return Patch_Terminal_Input (Source, Platform);
      end if;
      return Source;
   end Patch_Source;

   function Transform (Name, Source, Platform : String) return String is
   begin
      if Index (Source, [1 => CR]) = 0 then
         return Patch_Source (Name, Source, Platform);
      end if;

      declare
         Normalized : constant String :=
           Replace
             (Replace (Source, CR & LF, [1 => LF]), [1 => CR], [1 => LF]);
         Updated    : constant String :=
           Patch_Source (Name, Normalized, Platform);
      begin
         return (if Updated = Normalized then Source else Updated);
      end;
   end Transform;
end Diary_Tooling_Patches;
