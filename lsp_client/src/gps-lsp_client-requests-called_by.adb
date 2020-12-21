------------------------------------------------------------------------------
--                               GNAT Studio                                --
--                                                                          --
--                        Copyright (C) 2019-2021, AdaCore                  --
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

with LSP.JSON_Streams;

with GPS.LSP_Client.Utilities;

package body GPS.LSP_Client.Requests.Called_By is

   ------------
   -- Method --
   ------------

   overriding function Method
     (Self : Abstract_Called_By_Request) return String
   is
      pragma Unreferenced (Self);

   begin
      return "textDocument/alsCalledBy";
   end Method;

   ------------
   -- Method --
   ------------

   overriding function Method
     (Self : Abstract_Calls_Request) return String
   is
      pragma Unreferenced (Self);

   begin
      return "textDocument/alsCalls";
   end Method;

   -----------------------
   -- On_Result_Message --
   -----------------------

   overriding procedure On_Result_Message
     (Self   : in out Abstract_Calls_Or_Called_By_Request;
      Stream : not null access LSP.JSON_Streams.JSON_Stream'Class)
   is
      Results : LSP.Messages.ALS_Subprogram_And_References_Vector;

   begin
      LSP.Messages.ALS_Subprogram_And_References_Vector'Read
        (Stream, Results);
      Abstract_Calls_Or_Called_By_Request'Class
        (Self).On_Result_Message (Results);
   end On_Result_Message;

   ------------
   -- Params --
   ------------

   function Params
     (Self : Abstract_Calls_Or_Called_By_Request)
      return LSP.Messages.TextDocumentPositionParams is
   begin
      return
        (textDocument =>
           (uri => GPS.LSP_Client.Utilities.To_URI (Self.File)),
         position     => Self.Position);
   end Params;

   --------------------------
   -- Is_Request_Supported --
   --------------------------

   overriding function Is_Request_Supported
     (Self    : Abstract_Calls_Or_Called_By_Request;
      Options : LSP.Messages.ServerCapabilities)
      return Boolean is
   begin
      return True;
   end Is_Request_Supported;

   ------------
   -- Params --
   ------------

   overriding procedure Params
     (Self   : Abstract_Calls_Or_Called_By_Request;
      Stream : not null access LSP.JSON_Streams.JSON_Stream'Class) is
   begin
      LSP.Messages.TextDocumentPositionParams'Write (Stream, Self.Params);
   end Params;

end GPS.LSP_Client.Requests.Called_By;
