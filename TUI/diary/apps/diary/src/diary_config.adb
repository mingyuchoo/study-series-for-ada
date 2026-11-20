with Ada.Characters.Handling;
with Ada.Characters.Latin_1;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Maps;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNAT.OS_Lib;

package body Diary_Config is
   use Ada.Strings.Unbounded;
   Whitespace : constant Ada.Strings.Maps.Character_Set :=
     Ada.Strings.Maps.To_Set (" " & Ada.Characters.Latin_1.HT);
   function Clean (Value : String) return String
   is (Ada.Strings.Fixed.Trim (Value, Whitespace, Whitespace));
   function File_Name return String is
      Home : constant String := Ada.Environment_Variables.Value ("HOME", "");
   begin
      if Home = "" then
         raise Config_Error with "Set HOME to load or save diary settings";
      end if;
      return Home & "/.ada_tui_diary/config.toml";
   end File_Name;
   function Uncomment (Value : String) return String is
      Quote   : Character := ASCII.NUL;
      Escaped : Boolean := False;
   begin
      for Index in Value'Range loop
         if Escaped then
            Escaped := False;
         elsif Quote = '"' and then Value (Index) = '\' then
            Escaped := True;
         elsif Quote /= ASCII.NUL then
            if Value (Index) = Quote then
               Quote := ASCII.NUL;
            end if;
         elsif Value (Index) in '"' | ''' then
            Quote := Value (Index);
         elsif Value (Index) = '#' then
            return Value (Value'First .. Index - 1);
         end if;
      end loop;
      return Value;
   end Uncomment;
   function Unquote (Value : String) return String is
      Result  : Unbounded_String;
      Escaped : Boolean := False;
   begin
      if Value'Length < 2
        or else Value (Value'First) not in '"' | '''
        or else Value (Value'First) /= Value (Value'Last)
      then
         raise Config_Error with "Expected a quoted string";
      end if;
      for Index in Value'First + 1 .. Value'Last - 1 loop
         if Escaped then
            if Value (Index) not in '"' | '\' then
               raise Config_Error
                 with "Only quote and backslash escapes are supported";
            end if;
            Append (Result, Value (Index));
            Escaped := False;
         elsif Value (Value'First) = '"' and then Value (Index) = '\' then
            Escaped := True;
         elsif Value (Index) = Value (Value'First) then
            raise Config_Error with "Unexpected quote in string";
         else
            Append (Result, Value (Index));
         end if;
      end loop;
      if Escaped then
         raise Config_Error with "Incomplete string escape";
      end if;
      return To_String (Result);
   end Unquote;
   function Quoted (Value : String) return String is
      Result : Unbounded_String := To_Unbounded_String ("""");
   begin
      for Letter of Value loop
         if Letter in '"' | '\' then
            Append (Result, '\');
         end if;
         Append (Result, Letter);
      end loop;
      Append (Result, '"');
      return To_String (Result);
   end Quoted;
   function Load_Settings return Diary_Bindings.Preferences is
      use Ada.Strings.Fixed;
      use Diary_Bindings;
      File          : Ada.Text_IO.File_Type;
      Name          : constant String :=
        (if Ada.Environment_Variables.Value ("HOME", "") = ""
         then ""
         else File_Name);
      type Table_Kind is (No_Table, Editor_Table, Emacs_Table, Helix_Table);
      Table         : Table_Kind := No_Table;
      Seen_Tables   : array (Table_Kind) of Boolean := [others => False];
      Seen_Keymap   : Boolean := False;
      Seen_Bindings : array (Diary_Keymaps.Kind, Action_Id) of Boolean :=
        [others => [others => False]];
      Result        : Preferences;
      Line          : Natural := 0;
      procedure Invalid (Detail : String) is
      begin
         raise Config_Error with Detail;
      end Invalid;
   begin
      if Name = "" or else not Ada.Directories.Exists (Name) then
         return Result;
      end if;
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Name);
      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Text  : constant String :=
              Clean (Uncomment (Ada.Text_IO.Get_Line (File)));
            Equal : constant Natural := Index (Text, "=");
         begin
            Line := Line + 1;
            if Text = "" then
               null;
            elsif Text (Text'First) = '[' then
               if Text = "[editor]" then
                  Table := Editor_Table;
               elsif Text = "[bindings.emacs]" then
                  Table := Emacs_Table;
               elsif Text = "[bindings.helix]" then
                  Table := Helix_Table;
               else
                  Invalid ("Unknown settings table: " & Text);
               end if;
               if Seen_Tables (Table) then
                  Invalid ("Duplicate settings table: " & Text);
               end if;
               Seen_Tables (Table) := True;
            elsif Equal > 0 and then Table /= No_Table then
               declare
                  Key   : constant String :=
                    Clean (Text (Text'First .. Equal - 1));
                  Value : constant String :=
                    Unquote (Clean (Text (Equal + 1 .. Text'Last)));
               begin
                  if Table = Editor_Table then
                     if Key /= "keymap" or else Seen_Keymap then
                        Invalid ("Unknown or duplicate editor key: " & Key);
                     end if;
                     if Value = "emacs" then
                        Result.Keymap := Diary_Keymaps.Emacs;
                     elsif Value = "helix" then
                        Result.Keymap := Diary_Keymaps.Helix;
                     else
                        Invalid ("Unknown keymap: " & Value);
                     end if;
                     Seen_Keymap := True;
                  else
                     declare
                        Keymap : constant Diary_Keymaps.Kind :=
                          (if Table = Emacs_Table
                           then Diary_Keymaps.Emacs
                           else Diary_Keymaps.Helix);
                        Action : constant Action_Id := Action_Named (Key);
                     begin
                        if not Supported (Keymap, Action) then
                           Invalid
                             ("Action is unavailable in this keymap: " & Key);
                        end if;
                        if Seen_Bindings (Keymap, Action) then
                           Invalid ("Duplicate binding: " & Key);
                        end if;
                        Result.Bindings (Keymap, Action) := Parse (Value);
                        Seen_Bindings (Keymap, Action) := True;
                     end;
                  end if;
               end;
            else
               Invalid ("Expected a settings table and key = quoted value");
            end if;
         end;
      end loop;
      declare
         Error : constant String := Validate (Result.Bindings);
      begin
         if Error /= "" then
            Invalid (Error);
         end if;
      end;
      Ada.Text_IO.Close (File);
      return Result;
   exception
      when Error : others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         raise Config_Error
           with
             Name
             & ":"
             & Natural'Image (Line)
             & ": "
             & Ada.Exceptions.Exception_Message (Error);
   end Load_Settings;
   function Load return Diary_Keymaps.Kind
   is (Load_Settings.Keymap);
   procedure Save (Value : Diary_Bindings.Preferences) is
      use Diary_Bindings;
      File             : Ada.Text_IO.File_Type;
      Name             : constant String := File_Name;
      Temporary        : constant String := Name & ".tmp";
      Renamed, Created : Boolean := False;
      Original         : constant Binding_Table := Defaults;
      Previous         : constant Preferences := Load_Settings;
      pragma Unreferenced (Previous);
      Error            : constant String := Validate (Value.Bindings);
   begin
      if Error /= "" then
         raise Config_Error with Error;
      end if;
      Ada.Directories.Create_Path
        (Ada.Directories.Containing_Directory (Name));
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Temporary);
      Created := True;
      Ada.Text_IO.Put_Line (File, "[editor]");
      Ada.Text_IO.Put_Line
        (File,
         "keymap = "
         & Quoted
             (Ada.Characters.Handling.To_Lower
                (Diary_Keymaps.Kind'Image (Value.Keymap))));
      for Keymap in Diary_Keymaps.Kind loop
         Ada.Text_IO.New_Line (File);
         Ada.Text_IO.Put_Line
           (File,
            "[bindings."
            & Ada.Characters.Handling.To_Lower
                (Diary_Keymaps.Kind'Image (Keymap))
            & "]");
         for Action in Action_Id loop
            if Value.Bindings (Keymap, Action) /= Original (Keymap, Action)
            then
               Ada.Text_IO.Put_Line
                 (File,
                  Diary_Bindings.Name (Action)
                  & " = "
                  & Quoted (Image (Value.Bindings (Keymap, Action))));
            end if;
         end loop;
      end loop;
      Ada.Text_IO.Close (File);
      GNAT.OS_Lib.Rename_File (Temporary, Name, Renamed);
      if not Renamed then
         raise Config_Error with "Cannot replace " & Name;
      end if;
   exception
      when Error : others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         if Created and then Ada.Directories.Exists (Temporary) then
            Ada.Directories.Delete_File (Temporary);
         end if;
         raise Config_Error with Ada.Exceptions.Exception_Message (Error);
   end Save;
   procedure Save (Keymap : Diary_Keymaps.Kind) is
      Value : Diary_Bindings.Preferences := Load_Settings;
   begin
      Value.Keymap := Keymap;
      Save (Value);
   end Save;
end Diary_Config;
