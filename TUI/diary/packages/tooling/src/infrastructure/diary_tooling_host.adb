with GNAT.OS_Lib;
with Interfaces.C;
with System;

package body Diary_Tooling_Host is
   function Uname (Information : System.Address) return Interfaces.C.int
   with Import, Convention => C, External_Name => "uname";

   function Platform return String is
      use Interfaces.C;
      Information : aliased char_array (0 .. 4095) := [others => nul];
   begin
      if Uname (Information'Address) /= 0 then
         raise Program_Error
           with "Host discovery failed: " & GNAT.OS_Lib.Errno_Message;
      end if;
      declare
         Name : constant String := To_Ada (Information);
      begin
         if Name = "Linux" then
            return "linux";
         elsif Name = "Darwin" then
            return "macos";
         end if;
         raise Program_Error with "Unsupported host: " & Name;
      end;
   end Platform;
end Diary_Tooling_Host;
