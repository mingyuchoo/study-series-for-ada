with Test_Fixtures;
with Test_Processes;

procedure Run_Storage_Tests is
   use Test_Fixtures;
   use Test_Processes;
   Directory : Temporary_Directory;
begin
   Create (Directory, "ada-diary-test-");
   Create_FIFO (Directory, "2024-02-27.diary");
   Check
     (Run
        (Sibling_Executable ("storage_tests"),
         [Argument (Path (Directory))],
         Timeout => 5.0)
      = 0,
      "Storage tests failed");
end Run_Storage_Tests;
