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
--
--  This package provides a basic support for partial result notification.
--

with LSP.Errors;
with LSP.Messages;

package LSP.Partial_Results is

   type Abstract_Batch_Cursor is limited interface;
   --  Abstract type of a cursor to fetch server response in batches

   function Is_Error
     (Self : Abstract_Batch_Cursor) return Boolean is abstract;
   --  Cursor fails and it is unable to return result

   procedure Get_Error
     (Self  : in out Abstract_Batch_Cursor;
      Value : out LSP.Errors.ResponseError) is abstract;
   --  with Pre'Class => Self.Is_Error
   --  Return the error response for a failed cursor

   function Has_Batch
     (Self : Abstract_Batch_Cursor) return Boolean is abstract;
   --  The cursor has the response batch

   type Empty_Batch_Cursor is limited new Abstract_Batch_Cursor with
     null record;
   --  Base type for empty cursors

   overriding function Is_Error
     (Self : Empty_Batch_Cursor) return Boolean is (False);
   --  Empty cursor never has an error

   overriding procedure Get_Error
     (Self  : in out Empty_Batch_Cursor;
      Value : out LSP.Errors.ResponseError) is null;
   --  Empty cursor never has an error, do nothing

   overriding function Has_Batch
     (Self : Empty_Batch_Cursor) return Boolean is (False);
   --  Empty cursor never has a batch

   type Completion_Batch_Cursor is limited interface and Abstract_Batch_Cursor;
   --  Cursor to return completions

   procedure Next_Completions
     (Self    : in out Completion_Batch_Cursor;
      Request : LSP.Messages.CompletionParams;
      Value   : in out LSP.Messages.CompletionList) is abstract;
   --  with Pre'Class => not Self.Is_Error and Self.Has_Batch;
   --  Return a batch and move the cursor to the next response batch

   type Reference_Batch_Cursor is limited interface and Abstract_Batch_Cursor;
   --  Cursor to return references

   procedure Next_References
     (Self    : in out Reference_Batch_Cursor;
      Request : LSP.Messages.ReferenceParams;
      Value   : in out LSP.Messages.Location_Vector) is abstract;
   --  with Pre'Class => not Self.Is_Error and Self.Has_Batch;
   --  Append a batch to Value and move the cursor to the next response batch

end LSP.Partial_Results;
