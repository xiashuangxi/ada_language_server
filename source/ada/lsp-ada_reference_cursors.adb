------------------------------------------------------------------------------
--                         Language Server Protocol                         --
--                                                                          --
--                     Copyright (C) 2018-2020, AdaCore                     --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public  License  distributed  with  this  software;   see  file --
-- COPYING3.  If not, go to http://www.gnu.org/licenses for a complete copy --
-- of the license.                                                          --
------------------------------------------------------------------------------

with Ada.Exceptions;
with Ada.Strings.UTF_Encoding;

package body LSP.Ada_Reference_Cursors is

   procedure Stabilize (Self : in out Reference_Cursor);
   --  Starting from Self.Context_Cursor iterate over the context list and find
   --  a context with Find_All_References return non empty set.
   --  On return Self.Context_Cursor has no element or else
   --  Self.Unit_Cursor.Has_More_References

   Warning_Text : constant Ada.Strings.UTF_Encoding.UTF_8_String :=
     "The results of 'references' are approximate.";

   ------------
   -- Create --
   ------------

   function Create
     (Documents : not null LSP.Ada_Documents.Document_Provider_Access;
      Server    : not null access LSP.Client_Message_Receivers
                    .Client_Message_Receiver'Class;
      Contexts  : LSP.Ada_Context_Sets.Context_Lists.List;
      Position  : LSP.Messages.ReferenceParams;
      Trace     : GNATCOLL.Traces.Trace_Handle)
      return Reference_Cursor
   is
   begin
      return Result : Reference_Cursor :=
        (Documents => Documents,
         Server    => Server,
         Contexts  => Contexts,
         Position  => Position,
         Trace     => Trace,
         Exact     => True,
         others    => <>)
      do
         Result.Context_Cursor := Result.Contexts.First;
         Stabilize (Result);
      end return;
   end Create;

   --------------
   -- Is_Error --
   --------------

   overriding function Is_Error (Self : Reference_Cursor) return Boolean is
   begin
      return not LSP.Types.Is_Empty (Self.Error);
   end Is_Error;

   ---------------
   -- Get_Error --
   ---------------

   overriding procedure Get_Error
     (Self  : in out Reference_Cursor;
      Value : out LSP.Errors.ResponseError) is
   begin
      Value :=
        (code    => LSP.Errors.InternalError,
         message => Self.Error,
         data    => <>);
   end Get_Error;

   ---------------
   -- Has_Batch --
   ---------------

   overriding function Has_Batch (Self : Reference_Cursor) return Boolean is
   begin
      return LSP.Ada_Context_Sets.Context_Lists.Has_Element
        (Self.Context_Cursor);
   end Has_Batch;

   ---------------------
   -- Next_References --
   ---------------------

   overriding procedure Next_References
     (Self    : in out Reference_Cursor;
      Request : LSP.Messages.ReferenceParams;
      Value   : in out LSP.Messages.Location_Vector)
   is
      Threshold : constant := 256;
      --  We stop after collecting Threshold items in Value

      Count : Natural := Threshold;
   begin
      while Count > 0 loop
         declare
            References : constant Libadalang.Analysis.Base_Id_Array :=
              Self.Unit_Cursor.Get_Next_References;
         begin
            for Node of References loop
               if not LSP.Lal_Utils.Is_End_Label (Node.As_Ada_Node) then
                  LSP.Lal_Utils.Append_Location
                    (Value,
                     Node,
                     LSP.Lal_Utils.Get_Reference_Kind
                       (Node.As_Ada_Node, Self.Trace));

                  Count := Count - 1;
               end if;
            end loop;

            if not Self.Unit_Cursor.Has_More_References then
               --  Take next context from the list
               LSP.Ada_Context_Sets.Context_Lists.Next (Self.Context_Cursor);
               --  Find good Self.Unit_Cursor
               Stabilize (Self);

               --  Exit when no more data
               if not LSP.Ada_Context_Sets.Context_Lists.Has_Element
                 (Self.Context_Cursor)
               then
                  --  Send a warrning if result was not exact
                  if not Self.Exact then
                     Self.Server.On_Show_Message
                       ((LSP.Messages.Warning,
                         LSP.Types.To_LSP_String (Warning_Text)));
                  end if;

                  exit;
               end if;
            end if;
         end;
      end loop;
   end Next_References;

   ---------------
   -- Stabilize --
   ---------------

   procedure Stabilize (Self : in out Reference_Cursor) is
      use type Libadalang.Analysis.Name;
      Definition : Libadalang.Analysis.Defining_Name;
      Imprecise  : Boolean := False;
      Context    : LSP.Ada_Context_Sets.Context_Access;
   begin
      while
        LSP.Ada_Context_Sets.Context_Lists.Has_Element (Self.Context_Cursor)
      loop
         Context :=
           LSP.Ada_Context_Sets.Context_Lists.Element (Self.Context_Cursor);

         Self.Name_Node := LSP.Lal_Utils.Get_Node_As_Name
           (Context.Get_Node_At
              (Self.Documents.Get_Open_Document
                 (Self.Position.textDocument.uri),
               Self.Position));

         if Self.Name_Node /= Libadalang.Analysis.No_Name then
            Definition := LSP.Lal_Utils.Resolve_Name
              (Self.Name_Node,
               Self.Trace,
               Imprecise => Imprecise);

            --  Self.Exact := Self.Exact and not Imprecise;
            Self.Unit_Cursor := Context.Find_All_References
              (Definition,
               Step => 111);

            exit when Self.Unit_Cursor.Has_More_References;
         end if;

         LSP.Ada_Context_Sets.Context_Lists.Next (Self.Context_Cursor);
      end loop;
   exception
      when E : others =>
         Self.Context_Cursor := LSP.Ada_Context_Sets.Context_Lists.No_Element;
         Self.Error := LSP.Types.To_LSP_String
           (Ada.Exceptions.Exception_Information (E));
   end Stabilize;

end LSP.Ada_Reference_Cursors;
