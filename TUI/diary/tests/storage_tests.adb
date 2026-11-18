with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;
with Ada.Strings.Wide_Wide_Unbounded;
with Diary_Dates;
with Diary_Entries;
with Diary_Repositories;
with Diary_Service;
with Diary_File_Repositories;

procedure Storage_Tests is
   use Ada.Strings.Wide_Wide_Unbounded;
   use type Diary_Entries.Entry_Data;
   use type Diary_Service.Outcome;
   Directory : constant String := Ada.Command_Line.Argument (1);
   Store : Diary_File_Repositories.File_Repository;
   Date_Value : constant Diary_Dates.Date := Diary_Dates.Create (2024, 2, 29);
   Item : Diary_Entries.Entry_Data := (Date_Value, To_Unbounded_Wide_Wide_String ("한글 제목"), To_Unbounded_Wide_Wide_String ("첫 줄" & Wide_Wide_Character'Val (10) & "두 번째 줄" & Wide_Wide_Character'Val (10)));
   procedure Check (Condition : Boolean; Name : String) is
   begin
      if not Condition then
         raise Program_Error with Name;
      end if;
   end Check;
   procedure Expect_Locked is
      Other : Diary_File_Repositories.File_Repository;
   begin
      Diary_File_Repositories.Open (Other, Directory);
      raise Program_Error with "Second store acquired lock";
   exception
      when Diary_Repositories.Storage_Error => null;
   end Expect_Locked;
begin
   Diary_File_Repositories.Open (Store, Directory);
   Check (not Diary_Service.Read (Store, Date_Value).Found, "missing entry");
   Check (Diary_Service.Update (Store, Item) = Diary_Service.Not_Found, "update requires existing");
   Check (Diary_Service.Delete (Store, Date_Value) = Diary_Service.Not_Found, "missing delete");
   Check (Diary_Service.Create (Store, Item) = Diary_Service.Success, "create");
   Check (Diary_Service.Create (Store, Item) = Diary_Service.Already_Exists, "duplicate rejected");
   Expect_Locked;
   begin
      Check (Diary_Service.Read (Store, Diary_Dates.Create (2024, 2, 27)).Found, "FIFO read outcome");
      raise Program_Error with "FIFO should be rejected";
   exception
      when Diary_Repositories.Storage_Error => null;
   end;
   Check (Diary_Service.Read (Store, Date_Value).Item = Item, "Unicode exact read");
   Diary_File_Repositories.Close (Store);
   Diary_File_Repositories.Open (Store, Directory);
   Check (Diary_Service.Read (Store, Date_Value).Item = Item, "restart persistence");
   Item.Title := To_Unbounded_Wide_Wide_String ("Updated");
   Item.Content := Null_Unbounded_Wide_Wide_String;
   Check (Diary_Service.Update (Store, Item) = Diary_Service.Success, "update");
   Check (Diary_Service.Read (Store, Date_Value).Item = Item, "updated content");
   Check (Diary_Service.Month_Days (Store, Date_Value) (29), "calendar mark");
   Ada.Directories.Create_Directory (Directory & "/2024-02-28.diary");
   Check (Diary_Service.Month_Days (Store, Date_Value) (29), "bad neighbor does not block month");
   Check (Diary_Service.Read (Store, Date_Value).Found, "bad neighbor does not block read");
   Ada.Directories.Delete_Directory (Directory & "/2024-02-28.diary");
   Item.Title := To_Unbounded_Wide_Wide_String (" ");
   Check (Diary_Service.Update (Store, Item) = Diary_Service.Invalid_Entry, "blank title rejected");
   Check (To_Wide_Wide_String (Diary_Service.Read (Store, Date_Value).Item.Title) = "Updated", "invalid update preserves original");
   Item.Title := To_Unbounded_Wide_Wide_String ("Replacement");
   Ada.Directories.Create_Directory (Directory & "/2024-02-29.diary.tmp");
   begin
      Check (Diary_Service.Update (Store, Item) = Diary_Service.Success, "write outcome");
      raise Program_Error with "Write should fail";
   exception
      when Diary_Repositories.Storage_Error => null;
   end;
   Ada.Directories.Delete_Directory (Directory & "/2024-02-29.diary.tmp");
   Check (To_Wide_Wide_String (Diary_Service.Read (Store, Date_Value).Item.Title) = "Updated", "failed write preserves original");
   Check (Diary_Service.Delete (Store, Date_Value) = Diary_Service.Success, "delete");
   Check (not Diary_Service.Month_Days (Store, Date_Value) (29), "calendar unmark");
   declare
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Directory & "/2024-02-29.diary");
      Ada.Text_IO.Put_Line (File, "broken content");
      Ada.Text_IO.Close (File);
   end;
   begin
      Check (Diary_Service.Read (Store, Date_Value).Found, "corrupt read outcome");
      raise Program_Error with "Corrupt entry should fail";
   exception
      when Diary_Repositories.Storage_Error => null;
   end;
   Check (Ada.Directories.Exists (Directory & "/2024-02-29.diary"), "corrupt data preserved");
   Diary_File_Repositories.Close (Store);
   Ada.Text_IO.Put_Line ("PASS storage CRUD, restart, locks and failed writes");
end Storage_Tests;
