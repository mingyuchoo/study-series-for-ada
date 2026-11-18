with Ada.Strings.Fixed;
with Ada.Strings.Maps;
with Ada.Strings.Unbounded;

package body Tui_Tooling_Release is
   use Ada.Strings.Fixed;
   use Ada.Strings.Unbounded;
   Whitespace : constant Ada.Strings.Maps.Character_Set :=
     Ada.Strings.Maps.To_Set (" " & ASCII.HT & ASCII.CR & ASCII.LF);
   function Trimmed (Value : String) return String
   is (Trim (Value, Whitespace, Whitespace));
   function Starts_With (Value, Prefix : String) return Boolean
   is (Value'Length >= Prefix'Length
       and then Value (Value'First .. Value'First + Prefix'Length - 1)
                = Prefix);
   function Version_Valid (Value : String) return Boolean is
      Position : Integer := Value'First;
   begin
      for Component in 1 .. 3 loop
         declare
            Start : constant Integer := Position;
         begin
            while Position <= Value'Last
              and then Value (Position) in '0' .. '9'
            loop
               Position := Position + 1;
            end loop;
            if Position = Start then
               return False;
            end if;
         end;
         if Component < 3 then
            if Position > Value'Last or else Value (Position) /= '.' then
               return False;
            end if;
            Position := Position + 1;
         end if;
      end loop;
      if Position > Value'Last then
         return True;
      end if;
      if Value (Position) /= '-' then
         return False;
      end if;
      Position := Position + 1;
      declare
         Need_Character : Boolean := True;
      begin
         while Position <= Value'Last loop
            if Value (Position) in '0' .. '9' | 'A' .. 'Z' | 'a' .. 'z' then
               Need_Character := False;
            elsif Value (Position) in '.' | '-' and then not Need_Character
            then
               Need_Character := True;
            else
               return False;
            end if;
            Position := Position + 1;
         end loop;
         return not Need_Character;
      end;
   end Version_Valid;
   function Manifest_Version (Source : String) return String is
      Result   : Unbounded_String;
      Count    : Natural := 0;
      Position : Integer := Source'First;
   begin
      while Position <= Source'Last loop
         declare
            Finish : Integer := Position;
         begin
            while Finish <= Source'Last and then Source (Finish) /= ASCII.LF
            loop
               Finish := Finish + 1;
            end loop;
            declare
               Line  : constant String :=
                 Trimmed (Source (Position .. Finish - 1));
               Equal : constant Natural := Index (Line, "=");
            begin
               exit when Starts_With (Line, "[");
               if Equal > 0
                 and then Trimmed (Line (Line'First .. Equal - 1)) = "version"
               then
                  declare
                     Value   : constant String :=
                       Trimmed (Line (Equal + 1 .. Line'Last));
                     Closing : constant Natural :=
                       Index (Value, """", Value'First + 1);
                  begin
                     if Value'Length < 2
                       or else Value (Value'First) /= '"'
                       or else Closing = 0
                     then
                        raise Constraint_Error
                          with "Invalid version in manifest";
                     end if;
                     declare
                        Tail    : constant String :=
                          Trimmed (Value (Closing + 1 .. Value'Last));
                        Version : constant String :=
                          Value (Value'First + 1 .. Closing - 1);
                     begin
                        if not Version_Valid (Version)
                          or else (Tail'Length > 0
                                   and then Tail (Tail'First) /= '#')
                        then
                           raise Constraint_Error
                             with "Invalid version in manifest";
                        end if;
                        Result := To_Unbounded_String (Version);
                        Count := Count + 1;
                     end;
                  end;
               end if;
            end;
            Position := Finish + 1;
         end;
      end loop;
      if Count /= 1 then
         raise Constraint_Error
           with "Expected exactly one top-level manifest version";
      end if;
      return To_String (Result);
   end Manifest_Version;
   function Pin_Manifest (Source : String) return String is
      Result   : Unbounded_String;
      Count    : Natural := 0;
      Position : Integer := Source'First;
      In_Pins  : Boolean := False;
   begin
      while Position <= Source'Last loop
         declare
            Finish : Integer := Position;
         begin
            while Finish <= Source'Last and then Source (Finish) /= ASCII.LF
            loop
               Finish := Finish + 1;
            end loop;
            declare
               Line  : constant String :=
                 Trimmed (Source (Position .. Finish - 1));
               Equal : constant Natural := Index (Line, "=");
            begin
               if Starts_With (Line, "[") then
                  In_Pins := Line = "[[pins]]";
               end if;
               if In_Pins
                 and then Equal > 0
                 and then Trimmed (Line (Line'First .. Equal - 1)) = "malef"
               then
                  declare
                     Value : constant String :=
                       Trimmed (Line (Equal + 1 .. Line'Last));
                  begin
                     if Value'Length < 2
                       or else Value (Value'First) /= '{'
                       or else Value (Value'Last) /= '}'
                     then
                        raise Constraint_Error with "Invalid Malef source pin";
                     end if;
                     declare
                        Table_Value : constant String :=
                          Trimmed (Value (Value'First + 1 .. Value'Last - 1));
                        Assignment  : constant Natural :=
                          Index (Table_Value, "=");
                     begin
                        if Assignment = 0 then
                           raise Constraint_Error
                             with "Missing Malef source assignment";
                        end if;
                        declare
                           Key      : constant String :=
                             Trimmed
                               (Table_Value
                                  (Table_Value'First .. Assignment - 1));
                           Location : constant String :=
                             Trimmed
                               (Table_Value
                                  (Assignment + 1 .. Table_Value'Last));
                        begin
                           if (Key /= "url" and then Key /= "path")
                             or else Location'Length < 3
                             or else Location (Location'First) not in '"' | '''
                           then
                              raise Constraint_Error
                                with "Invalid Malef source assignment";
                           end if;
                        end;
                     end;
                  end;
                  Append (Result, "malef = { path = ""dependencies/malef"" }");
                  Count := Count + 1;
               else
                  Append (Result, Source (Position .. Finish - 1));
               end if;
               if Finish <= Source'Last then
                  Append (Result, ASCII.LF);
               end if;
            end;
            Position := Finish + 1;
         end;
      end loop;
      if Count /= 1 then
         raise Constraint_Error with "Expected exactly one Malef source pin";
      end if;
      return To_String (Result);
   end Pin_Manifest;
   function Numeric_Suffix
     (Name, Prefix : String; Dots : Boolean := False) return Boolean is
   begin
      if not Starts_With (Name, Prefix) or else Name'Length = Prefix'Length
      then
         return False;
      end if;
      for Character_Value of Name (Name'First + Prefix'Length .. Name'Last)
      loop
         if Character_Value not in '0' .. '9'
           and then not (Dots and then Character_Value = '.')
         then
            return False;
         end if;
      end loop;
      return True;
   end Numeric_Suffix;
   function Linux_Library (Name : String) return Boolean is
      Loader : constant Natural := Index (Name, "/ld-linux");
      Suffix : constant Natural := Index (Name, ".so.");
   begin
      return
        Numeric_Suffix (Name, "linux-vdso.so.")
        or else Numeric_Suffix (Name, "libc.so.")
        or else Numeric_Suffix (Name, "libm.so.")
        or else Numeric_Suffix (Name, "libpthread.so.")
        or else Numeric_Suffix (Name, "libdl.so.")
        or else Numeric_Suffix (Name, "librt.so.")
        or else (Name'Length > 0
                 and then Name (Name'First) = '/'
                 and then Loader > 0
                 and then Suffix > Loader
                 and then Index (Name (Loader + 1 .. Name'Last), "/") = 0
                 and then Numeric_Suffix
                            (Name (Suffix .. Name'Last), ".so.", True));
   end Linux_Library;
   function Dependencies_Allowed (Source, Platform : String) return Boolean is
      Position    : Integer := Source'First;
      Count       : Natural := 0;
      Header_Seen : Boolean := False;
   begin
      if Platform /= "linux" and then Platform /= "macos" then
         return False;
      end if;
      while Position <= Source'Last loop
         declare
            Finish : Integer := Position;
         begin
            while Finish <= Source'Last and then Source (Finish) /= ASCII.LF
            loop
               Finish := Finish + 1;
            end loop;
            declare
               Line     : constant String :=
                 Trimmed (Source (Position .. Finish - 1));
               End_Name : Integer := Line'First;
            begin
               if Line'Length > 0 then
                  if Platform = "macos" and then not Header_Seen then
                     if Line (Line'Last) /= ':' then
                        return False;
                     end if;
                     Header_Seen := True;
                  else
                     while End_Name <= Line'Last
                       and then Line (End_Name) not in ' ' | ASCII.HT
                     loop
                        End_Name := End_Name + 1;
                     end loop;
                     if Index (Line, "not found") > 0 then
                        return False;
                     end if;
                     if Platform = "linux" then
                        if not Linux_Library
                                 (Line (Line'First .. End_Name - 1))
                        then
                           return False;
                        end if;
                     elsif not Starts_With (Line, "/usr/lib/")
                       and then not Starts_With (Line, "/System/Library/")
                     then
                        return False;
                     end if;
                     Count := Count + 1;
                  end if;
               end if;
            end;
            Position := Finish + 1;
         end;
      end loop;
      return Count > 0;
   end Dependencies_Allowed;
end Tui_Tooling_Release;
