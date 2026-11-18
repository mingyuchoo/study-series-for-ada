with Ada.Finalization;
with GNAT.OS_Lib;
with Interfaces.C;

package Test_POSIX is
   type Host_Kind is (Linux, Darwin);
   Interrupted : constant := 4;

   function Host return Host_Kind;
   procedure Check_Result (Result : Interfaces.C.int; Operation : String);

   type Descriptor is new Ada.Finalization.Limited_Controlled with private;

   procedure Own
     (Object    : in out Descriptor;
      Handle    : GNAT.OS_Lib.File_Descriptor;
      Operation : String);
   function Handle (Object : Descriptor) return GNAT.OS_Lib.File_Descriptor;
   procedure Make_Nonblocking (Object : Descriptor; Platform : Host_Kind);

private
   type Descriptor is new Ada.Finalization.Limited_Controlled with record
      Value : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   end record;

   overriding
   procedure Finalize (Object : in out Descriptor);
end Test_POSIX;
