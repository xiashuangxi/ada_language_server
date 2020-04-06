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

with Ada.Containers.Hashed_Sets;

with GNATCOLL.Traces;

with Libadalang.Analysis;

with LSP.Ada_Context_Sets;
with LSP.Ada_Contexts;
with LSP.Ada_Documents;
with LSP.Client_Message_Receivers;
with LSP.Errors;
with LSP.Lal_Utils;
with LSP.Messages;
with LSP.Partial_Results;
with LSP.Types;

package LSP.Ada_Reference_Cursors is

   type Reference_Cursor
     (Documents : not null LSP.Ada_Documents.Document_Provider_Access)
   is limited new LSP.Partial_Results.Reference_Batch_Cursor with private;
   --  Implementation of find all references cursor

   overriding function Is_Error (Self : Reference_Cursor) return Boolean;

   overriding procedure Get_Error
     (Self  : in out Reference_Cursor;
      Value : out LSP.Errors.ResponseError);

   overriding function Has_Batch (Self : Reference_Cursor) return Boolean;

   overriding procedure Next_References
     (Self    : in out Reference_Cursor;
      Request : LSP.Messages.ReferenceParams;
      Value   : in out LSP.Messages.Location_Vector);

   function Create
     (Documents : not null LSP.Ada_Documents.Document_Provider_Access;
      Server    : not null access LSP.Client_Message_Receivers
                    .Client_Message_Receiver'Class;
      Contexts  : LSP.Ada_Context_Sets.Context_Lists.List;
      Position  : LSP.Messages.ReferenceParams;
      Trace     : GNATCOLL.Traces.Trace_Handle)
     return Reference_Cursor;
   --  Create new reference cursor.
   --  Server - to send an approximate warning.
   --  Documents - to retrive unsaved documents.
   --  Contexts - list of context to perfome search.
   --  Position - identifier position.
   --  Trace - to log Property_Error exception.

private

   package Location_Sets is new Ada.Containers.Hashed_Sets
     (Element_Type        => LSP.Messages.Location,
      Hash                => LSP.Lal_Utils.Hash,
      Equivalent_Elements => LSP.Messages."=",
      "="                 => LSP.Messages."=");
   --  Set of Location to filter duplicates in the result.

   type Reference_Cursor
     (Documents : not null LSP.Ada_Documents.Document_Provider_Access) is
      limited new LSP.Partial_Results.Reference_Batch_Cursor with
   record
      Server         : not null access LSP.Client_Message_Receivers
                         .Client_Message_Receiver'Class;
      Contexts       : LSP.Ada_Context_Sets.Context_Lists.List;
      Position       : LSP.Messages.ReferenceParams;
      Trace          : GNATCOLL.Traces.Trace_Handle;
      --  Trace - to log Property_Error exception.
      Context_Cursor : LSP.Ada_Context_Sets.Context_Lists.Cursor;
      --  A current context
      Name_Node      : Libadalang.Analysis.Name;
      --  A name node in the current context, that corresponds to the Position
      Unit_Cursor    : LSP.Ada_Contexts.All_Reference_Cursor;
      --  A current unit of the context
      Error          : LSP.Types.LSP_String;
      --  A current unit of the context
      Already_Seen   : Location_Sets.Set;
      --  Duplication filter
      Exact          : Boolean;
      --  Returned result is still exact
   end record;

end LSP.Ada_Reference_Cursors;
