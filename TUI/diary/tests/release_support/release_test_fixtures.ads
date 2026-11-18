with Ada.Finalization;
with Ada.Strings.Unbounded;
with Release_Test_Processes;

package Release_Test_Fixtures is
   type Fixture is limited private;

   function Create (Project_Root : String) return Fixture;
   function Directory (Test : Fixture) return String;
   function Project (Test : Fixture) return String;
   function Output (Test : Fixture) return String;
   function Log (Test : Fixture) return String;
   function Tools (Test : Fixture) return String;

   procedure Configure_Darwin
     (Test : Fixture; Isolate_Path : Boolean := False);
   procedure Create_Dependency (Location : String);

   function Run_Release
     (Test         : Fixture;
      Options      : Release_Test_Processes.Arguments;
      Fail_On      : String := "";
      Mask         : String := "022";
      Isolate_Path : Boolean := False) return Release_Test_Processes.Result;
   function Run_Prepare (Test : Fixture) return Release_Test_Processes.Result;

private
   type Fixture is new Ada.Finalization.Limited_Controlled with record
      Root : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   overriding
   procedure Finalize (Test : in out Fixture);
end Release_Test_Fixtures;
