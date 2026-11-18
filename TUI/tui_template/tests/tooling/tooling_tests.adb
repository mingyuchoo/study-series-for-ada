with Ada.Text_IO;
with Tui_Tooling_Release;

procedure Tooling_Tests is
   use Tui_Tooling_Release;
   Newline  : constant Character := ASCII.LF;
   procedure Check (Condition : Boolean; Name : String) is
   begin
      if not Condition then
         raise Program_Error with Name;
      end if;
   end Check;
   procedure Reject_Version (Source : String) is
   begin
      declare
         Value : constant String := Manifest_Version (Source);
      begin
         raise Program_Error with "Accepted invalid version: " & Value;
      end;
   exception
      when Constraint_Error =>
         null;
   end Reject_Version;
   procedure Reject_Pin (Source : String) is
   begin
      declare
         Value : constant String := Pin_Manifest (Source);
      begin
         raise Program_Error with "Accepted invalid pin: " & Value;
      end;
   exception
      when Constraint_Error =>
         null;
   end Reject_Pin;
   Manifest : constant String :=
     "name = ""tui_template"""
     & Newline
     & "version = ""1.2.3-rc.1-alpha"""
     & Newline
     & "[[depends-on]]"
     & Newline
     & "malef = ""*"""
     & Newline
     & "[[pins]]"
     & Newline
     & "malef = { url = ""https://example.test/malef"", commit = ""abc"" }"
     & Newline;
   Pinned   : constant String :=
     "name = ""tui_template"""
     & Newline
     & "version = ""1.2.3-rc.1-alpha"""
     & Newline
     & "[[depends-on]]"
     & Newline
     & "malef = ""*"""
     & Newline
     & "[[pins]]"
     & Newline
     & "malef = { path = ""dependencies/malef"" }"
     & Newline;
begin
   Check
     (Manifest_Version (Manifest) = "1.2.3-rc.1-alpha", "manifest version");
   Check
     (Manifest_Version ("version = ""0.1.0"" # stable") = "0.1.0",
      "inline comment");
   Reject_Version ("name = ""missing""");
   Reject_Version ("version = ""../bad""");
   Reject_Version ("version = ""1.2.3""" & Newline & "version = ""2.3.4""");
   Reject_Version ("[[package]]" & Newline & "version = ""1.2.3""");
   Reject_Version ("version = ""1.2.3-""");
   Check (Pin_Manifest (Manifest) = Pinned, "rewrite only source pin");
   Check (Pin_Manifest (Pinned) = Pinned, "pin is idempotent");
   Reject_Pin ("malef = ""*""");
   Reject_Pin ("[[pins]]" & Newline & "malef = { commit = ""path"" }");
   Reject_Pin ("[[pins]]" & Newline & "malef = { commit = ""url"" }");
   Reject_Pin ("[[pins]]" & Newline & "malef = { otherpath = ""source"" }");
   Reject_Pin (Pinned & "malef = { path = ""other"" }" & Newline);
   Check
     (Dependencies_Allowed
        ("linux-vdso.so.1 (0x123)"
         & Newline
         & "libc.so.6 => /lib/libc.so.6 (0x456)"
         & Newline
         & "/lib/ld-linux-aarch64.so.1 (0x789)"
         & Newline,
         "linux"),
      "OS runtime accepted");
   Check
     (Dependencies_Allowed
        (ASCII.HT
         & "linux-vdso.so.1 (0x123)"
         & ASCII.CR
         & Newline
         & ASCII.HT
         & "libc.so.6 => /lib/libc.so.6 (0x456)"
         & Newline
         & ASCII.HT
         & "/lib/ld-linux-aarch64.so.1 (0x789)"
         & Newline,
         "linux"),
      "ldd tab indentation and CRLF accepted");
   Check
     (not Dependencies_Allowed
            ("libgnat.so.16 => /lib/libgnat.so.16", "linux"),
      "Ada runtime must be bundled");
   Check
     (not Dependencies_Allowed ("libc.so.6 => not found", "linux"),
      "missing runtime rejected");
   Check
     (not Dependencies_Allowed ("", "linux"),
      "empty dependency listing rejected");
   Check
     (Dependencies_Allowed
        ("tui_template:"
         & Newline
         & "  /usr/lib/libSystem.B.dylib (compatibility version 1.0.0)"
         & Newline,
         "macos"),
      "macOS system runtime");
   Check
     (not Dependencies_Allowed
            ("tui_template:" & Newline & "  /opt/lib/libgnat.dylib", "macos"),
      "macOS external runtime rejected");
   Check
     (not Dependencies_Allowed ("/usr/lib/libSystem.B.dylib", "unknown"),
      "unknown platform rejected");
   Ada.Text_IO.Put_Line
     ("PASS release manifest policies and runtime dependency validation");
end Tooling_Tests;
