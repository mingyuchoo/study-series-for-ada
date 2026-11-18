from pathlib import Path
import re
import sys
import termios

ROOT = Path(__file__).resolve().parents[1]
LOCAL_SOURCE = ROOT / "dependencies/malef/src"
SOURCE = LOCAL_SOURCE if LOCAL_SOURCE.is_dir() else ROOT / "alire/cache/pins/malef_79b20b6b/src"
for name in ["drawing/malef-groups", "widgets/malef-styles", "widgets/malef-styles-classes", "widgets/malef-styles-sheets"]:
    path = SOURCE / f"{name}.ads"
    source = path.read_text()
    updated = re.sub(r"^\s*Put_Image\s*=> Put_Image,\n", "\n", source, flags=re.MULTILINE)
    if updated != source:
        path.write_text(updated)
path = SOURCE / "drawing/malef-groups.ads"
source = path.read_text()
updated = re.sub(
    r"(   function Last_Index \(\n      Object : in Group\)\n      return Layer_Count) is \(.*?Reduce \(Layer_Count'Max, 0\)\);",
    r"\1;", source, flags=re.DOTALL,
)
if updated != source:
    path.write_text(updated)
    body = SOURCE / "drawing/malef-groups.adb"
    text = body.read_text()
    text = text.replace("package body Malef.Groups is", """package body Malef.Groups is
   function Last_Index (Object : in Group) return Layer_Count is
   begin
      for Index in reverse 1 .. Object.Capacity loop
         if Contains (Object, Index) then
            return Index;
         end if;
      end loop;
      return 0;
   end Last_Index;""")
    body.write_text(text)
path = SOURCE / "drawing/malef-window.adb"
source = path.read_text()
updated = source.replace("Observer_Info'(Observer, Callback)", "Observer_Info'(Implementation.Observer_Access (Observer), Callback)").replace("Observer_Info'(Observer, null)", "Observer_Info'(Implementation.Observer_Access (Observer), null)")
if updated != source:
    path.write_text(updated)
path = SOURCE / "drawing/malef-palettes.adb"
source = path.read_text()
updated = source.replace(
    '''      return Integer is (
      [for I in Component_Name'Range =>
         (Integer (Left (I)) - Integer (Right (I))) ** 2]'Reduce ("+", 0));''',
    '''      return Integer is
      Result : Integer := 0;
   begin
      for Component in Component_Name loop
         Result := Result + (Integer (Left (Component)) - Integer (Right (Component))) ** 2;
      end loop;
      return Result;
   end Distance;''',
)
if updated != source:
    path.write_text(updated)
path = SOURCE / "private/malef-groups-composers.adb"
source = path.read_text()
updated = re.sub(r"(?<![.\w])Alpha\b", "Malef.Alpha", source)
updated = re.sub(r"(?<![.\w])Component_Type\b", "Malef.Component_Type", updated)
if updated != source:
    path.write_text(updated)
path = SOURCE / "private/malef-groups-composers.adb"
source = path.read_text()
updated = re.sub(
    r"   function Simple_Addition \(Top, Bottom : in RGBA_Type\)\n      return RGBA_Type is \(.*?\n      \)\);",
    '''   function Simple_Addition (Top, Bottom : in RGBA_Type)
      return RGBA_Type is
      W : Weights;
      Result : RGBA_Type;
   begin
      if Top (Malef.Alpha) = 255 then
         return Top;
      elsif Top (Malef.Alpha) = 0 then
         return Bottom;
      end if;
      W := Weight (Top, Bottom);
      for Component in Component_Name loop
         if Component = Malef.Alpha then
            Result (Component) := W.Alpha;
         else
            Result (Component) := Malef.Component_Type (Add (Float (Top (Component)) * W.Top, Float (Bottom (Component)) * W.Bottom));
         end if;
      end loop;
      return Result;
   end Simple_Addition;''', source, flags=re.DOTALL,
)
if updated != source:
    path.write_text(updated)
path = SOURCE / "subsystems/ansi/posix/__malef-platform-terminal-input-implementation.c"
source = path.read_text()
updated = source.replace("  new_term.c_lflag &= ~ICANON & ~ECHO;", "  new_term.c_lflag &= ~ICANON & ~ECHO;\n  new_term.c_iflag &= ~(IXON | ICRNL);") if "new_term.c_iflag &= ~(IXON | ICRNL);" not in source else source
if "new_term.c_lflag &= ~IEXTEN;" not in updated:
    updated = updated.replace("  new_term.c_iflag &= ~(IXON | ICRNL);", "  new_term.c_iflag &= ~(IXON | ICRNL);\n  new_term.c_lflag &= ~IEXTEN;")
if updated != source:
    path.write_text(updated)
path = SOURCE / "subsystems/ansi/posix/malef-platform-terminal-input-get_byte_immediate.adb"
source = path.read_text()
updated = source.replace("STDIN_FILENO : constant := 1;", "STDIN_FILENO : constant := 0;")
stdin_symbol = "__stdinp" if sys.platform == "darwin" else "stdin"
updated = re.sub(r'External_Name => "(?:stdin|__stdinp)"', f'External_Name => "{stdin_symbol}"', updated)
updated = updated.replace("      elsif Buffer = EOF_Ch then", "      elsif False and then Buffer = EOF_Ch then")
if updated != source:
    path.write_text(updated)
path = SOURCE / "subsystems/ansi/malef-platform-terminal-input.adb"
source = path.read_text()
updated = re.sub(
    r"TIOCGWINSZ : constant Interfaces.C.unsigned_long := 16#[0-9A-Fa-f]+#;",
    f"TIOCGWINSZ : constant Interfaces.C.unsigned_long := 16#{termios.TIOCGWINSZ:X}#;",
    source,
)
updated = updated.replace(
    """            if Key = Key_Type'Val (0) then
               Key := Key_Unknown;
            elsif Key = Key_Type'Val (27) then""",
    "            if Key = Key_Type'Val (27) then",
).replace(
    "      Rows := Row_Type (ws.ws_row);\n      Cols := Col_Type (ws.ws_col);",
    """      if Integer (temp) = 0
         and then Natural (ws.ws_row) in 1 .. Natural (Row_Type'Last)
         and then Natural (ws.ws_col) in 1 .. Natural (Col_Type'Last)
      then
         Rows := Row_Type (ws.ws_row);
         Cols := Col_Type (ws.ws_col);
      else
         Rows := 24;
         Cols := 80;
      end if;""",
)
if updated != source:
    path.write_text(updated)
