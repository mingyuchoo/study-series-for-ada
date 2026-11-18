with Ada.Directories;
with Ada.Exceptions;
with Ada.Streams.Stream_IO;
with GNAT.OS_Lib;
with Diary_File_Codec;

package body Diary_File_Repositories is
   use Ada.Strings.Unbounded;
   use type Ada.Streams.Stream_Element_Offset;
   use type Ada.Directories.File_Kind;
   procedure Ensure_Open (Store : File_Repository) is
   begin
      if not Store.Owns_Lock then
         raise Diary_Repositories.Storage_Error with "Repository is not open";
      end if;
   end Ensure_Open;
   function Filename
     (Store : File_Repository; Day : Diary_Dates.Date) return String is
   begin
      Ensure_Open (Store);
      return
        To_String (Store.Directory) & "/" & Diary_Dates.Image (Day) & ".diary";
   end Filename;
   procedure Open (Store : in out File_Repository; Directory : String) is
   begin
      if Store.Owns_Lock then
         raise Diary_Repositories.Storage_Error with "Repository already open";
      end if;
      Ada.Directories.Create_Path (Directory);
      Store.Directory :=
        To_Unbounded_String (Ada.Directories.Full_Name (Directory));
      begin
         Ada.Directories.Create_Directory
           (To_String (Store.Directory) & "/.lock");
      exception
         when Error : others =>
            raise Diary_Repositories.Storage_Error
              with
                "Cannot acquire diary lock (another session or stale .lock): "
                & Ada.Exceptions.Exception_Message (Error);
      end;
      Store.Owns_Lock := True;
   exception
      when Error : Ada.Directories.Name_Error | Ada.Directories.Use_Error =>
         raise Diary_Repositories.Storage_Error
           with Ada.Exceptions.Exception_Message (Error);
   end Open;
   procedure Close (Store : in out File_Repository) is
   begin
      if Store.Owns_Lock then
         Ada.Directories.Delete_Directory
           (To_String (Store.Directory) & "/.lock");
         Store.Owns_Lock := False;
      end if;
   end Close;
   overriding
   procedure Finalize (Store : in out File_Repository) is
   begin
      Close (Store);
   end Finalize;
   overriding
   function Contains
     (Store : in out File_Repository; Day : Diary_Dates.Date) return Boolean
   is
      Path : constant String := Filename (Store, Day);
   begin
      return Ada.Directories.Exists (Path);
   exception
      when Error : Ada.Directories.Name_Error | Ada.Directories.Use_Error =>
         raise Diary_Repositories.Storage_Error
           with Ada.Exceptions.Exception_Message (Error);
   end Contains;
   overriding
   function Read
     (Store : in out File_Repository; Day : Diary_Dates.Date)
      return Diary_Repositories.Entry_Result
   is
      File : Ada.Streams.Stream_IO.File_Type;
   begin
      if not Contains (Store, Day) then
         return (Found => False, others => <>);
      end if;
      if Ada.Directories.Kind (Filename (Store, Day))
        /= Ada.Directories.Ordinary_File
      then
         raise Diary_Repositories.Storage_Error
           with "Entry path is not a regular file";
      end if;
      Ada.Streams.Stream_IO.Open
        (File, Ada.Streams.Stream_IO.In_File, Filename (Store, Day));
      declare
         Data  :
           Ada.Streams.Stream_Element_Array
             (1
              .. Ada.Streams.Stream_Element_Offset
                   (Ada.Streams.Stream_IO.Size (File)));
         Last  : Ada.Streams.Stream_Element_Offset;
         Value : String (1 .. Data'Length);
      begin
         Ada.Streams.Stream_IO.Read (File, Data, Last);
         Ada.Streams.Stream_IO.Close (File);
         if Last /= Data'Last then
            raise Diary_Repositories.Storage_Error
              with "Incomplete diary read";
         end if;
         for Index in Value'Range loop
            Value (Index) :=
              Character'Val (Data (Ada.Streams.Stream_Element_Offset (Index)));
         end loop;
         return (True, Diary_File_Codec.Decode (Day, Value));
      end;
   exception
      when Error : others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise Diary_Repositories.Storage_Error
           with
             "Cannot read diary: " & Ada.Exceptions.Exception_Message (Error);
   end Read;
   overriding
   procedure Write
     (Store : in out File_Repository; Item : Diary_Entries.Entry_Data)
   is
      Target    : constant String := Filename (Store, Item.Day);
      Temporary : constant String := Target & ".tmp";
      Value     : constant String := Diary_File_Codec.Encode (Item);
      Data      :
        Ada.Streams.Stream_Element_Array
          (1 .. Ada.Streams.Stream_Element_Offset (Value'Length));
      File      : Ada.Streams.Stream_IO.File_Type;
      Renamed   : Boolean;
   begin
      for Index in Value'Range loop
         Data (Ada.Streams.Stream_Element_Offset (Index)) :=
           Character'Pos (Value (Index));
      end loop;
      Ada.Streams.Stream_IO.Create
        (File, Ada.Streams.Stream_IO.Out_File, Temporary);
      Ada.Streams.Stream_IO.Write (File, Data);
      Ada.Streams.Stream_IO.Close (File);
      GNAT.OS_Lib.Rename_File (Temporary, Target, Renamed);
      if not Renamed then
         raise Diary_Repositories.Storage_Error
           with "Cannot replace diary file";
      end if;
   exception
      when Error : others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise Diary_Repositories.Storage_Error
           with
             "Cannot save diary: " & Ada.Exceptions.Exception_Message (Error);
   end Write;
   overriding
   procedure Remove (Store : in out File_Repository; Day : Diary_Dates.Date) is
   begin
      Ada.Directories.Delete_File (Filename (Store, Day));
   exception
      when Error : others =>
         raise Diary_Repositories.Storage_Error
           with
             "Cannot delete diary: "
             & Ada.Exceptions.Exception_Message (Error);
   end Remove;
end Diary_File_Repositories;
