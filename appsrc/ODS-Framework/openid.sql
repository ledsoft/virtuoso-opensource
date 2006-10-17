--
--  $Id$
--
--  OpenID protocol support.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2006 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--


use OPENID;

DB.DBA.wa_exec_no_error_log (
'create table SERVER_SESSIONS
(
 SS_HANDLE varchar,
 SS_KEY_NAME varchar,
 SS_KEY varbinary,
 SS_KEY_TYPE varchar,
 SS_EXPIRY datetime,
 primary key (SS_HANDLE)
)');

insert soft "DB"."DBA"."SYS_SCHEDULED_EVENT" (SE_INTERVAL, SE_LAST_COMPLETED, SE_NAME, SE_SQL, SE_START)
  values (10, NULL, 'OPENID_SESSION_EXPIRE', 'delete from OPENID.DBA.SERVER_SESSIONS where SS_EXPIRY < now ()', now());

create procedure OPENID_INIT ()
{
  if (exists (select 1 from "DB"."DBA"."SYS_USERS" where U_NAME = 'OpenID'))
    return;
  DB.DBA.USER_CREATE ('OpenID', uuid(), vector ('DISABLED', 1, 'LOGIN_QUALIFIER', 'OPENID'));
}
;

OPENID_INIT ();

create procedure yadis (in uname varchar)
{
  http ('<?xml version="1.0" encoding="UTF-8"?>\n');
  http ('<xrds:XRDS \n');
  http ('  xmlns:xrds="xri://\044xrds" \n');
  http ('  xmlns:openid="http://openid.net/xmlns/1.0"   \n');
  http ('  xmlns="xri://\044xrd*(\044v*2.0)">\n');
  http ('  <XRD>\n');
  http ('    <Service priority="1">\n');
  http ('      <Type>http://openid.net/signon/1.0</Type>\n');
  http ('      <Type>http://openid.net/sreg/1.0</Type>\n');
  http (sprintf ('      <URI>%s</URI>\n', db.dba.wa_link (1, '/openid')));
  http ('      <openid:Delegate>'|| db.dba.wa_link (1, '/dataspace/'||uname)||'</openid:Delegate>\n');
  http ('    </Service>\n');
  http ('  </XRD>\n');
  http ('</xrds:XRDS>\n');
};

create procedure server
	(
	 in "openid.mode" varchar := 'unknown'
	)
	__SOAP_HTTP 'text/html'
{
  declare ret, lines, params, oid_sid, cookies_vec any;
  params := http_param ();
  lines := http_request_header ();

--  dbg_obj_print ('openid server lines=', lines);

  cookies_vec := DB.DBA.vsp_ua_get_cookie_vec (lines);
  oid_sid := get_keyword ('openid.sid', cookies_vec);

  if ("openid.mode" = 'associate')
    ret := associate (
    	get_keyword ('openid.assoc_type', params, 'HMAC-SHA1'),
    	get_keyword ('openid.session_type', params),
    	get_keyword ('openid.dh_modulus', params),
    	get_keyword ('openid.dh_gen', params),
    	get_keyword ('openid.dh_consumer_public', params));
  else if ("openid.mode" = 'checkid_immediate')
    ret := checkid_immediate (
    	get_keyword ('openid.identity', params),
    	get_keyword ('openid.assoc_handle', params),
    	get_keyword ('openid.return_to', params),
    	get_keyword ('openid.trust_root', params),
	oid_sid,
	0,
	get_keyword ('openid.sreg.required', params),
	get_keyword ('openid.sreg.optional', params),
	get_keyword ('openid.sreg.policy_url', params)
	);
  else if ("openid.mode" = 'checkid_setup')
    ret := checkid_setup (
    	get_keyword ('openid.identity', params),
    	get_keyword ('openid.assoc_handle', params),
    	get_keyword ('openid.return_to', params),
    	get_keyword ('openid.trust_root', params),
	oid_sid,
	get_keyword ('openid.sreg.required', params),
	get_keyword ('openid.sreg.optional', params),
	get_keyword ('openid.sreg.policy_url', params)
	);
  else if ("openid.mode" = 'check_authentication')
    ret := check_authentication (
    	get_keyword ('openid.assoc_handle', params),
    	get_keyword ('openid.sig', params),
    	get_keyword ('openid.signed', params),
    	get_keyword ('openid.invalidate_handle', params),
    	params,
	oid_sid);
  else
    ret := 'error:Unknown mode';
  return ret;
};

grant execute on server to "OpenID";

create procedure associate
    	(
	  in assoc_type varchar := 'HMAC-SHA1',
	  in session_type varchar := '',
	  in dh_modulus varchar := null,
	  in dh_gen varchar := null,
	  in dh_consumer_public varchar := null
	)
{
  declare assoc_handle, ses, ss_key, ss_key_data any;

  ses := string_output ();

  assoc_handle := md5 (datestring (now()));
  ss_key := 'OpenID_' || assoc_handle;
  xenc_key_3DES_rand_create (ss_key);
  ss_key_data := xenc_key_serialize (ss_key);
  insert into SERVER_SESSIONS (SS_HANDLE, SS_KEY_NAME, SS_KEY, SS_KEY_TYPE, SS_EXPIRY)
      values (assoc_handle, ss_key, ss_key_data, '3DES', dateadd ('hour', 1, now()));

  http (sprintf ('assoc_handle:%s\x0A', assoc_handle), ses);
  http ('assoc_type:HMAC-SHA1\x0A', ses);
  http (sprintf ('expires_in:%d\x0A', 60*60), ses);
  http (sprintf ('mac_key:%s\x0A', ss_key_data), ses);

  return string_output_string (ses);
};


create procedure checkid_immediate
	(
	 in _identity varchar,
	 in assoc_handle varchar := null,
	 in return_to varchar,
	 in trust_root varchar := null,
	 in sid varchar,
	 in flag int := 0, -- called via checkid_setup
	 in sreg_required varchar := null,
	 in sreg_optional varchar := null,
	 in policy_url varchar := null
    	)
{
  declare signature, rhf, delim any;
  declare login, hdr, usr varchar;

  if (trust_root is null)
    trust_root := _identity;

  if (length (_identity) = 0)
    return 'error:no_identity';
  if (length (return_to) = 0)
    return 'error:no_return_to';

--  dbg_obj_print ('checkid_immediate', sid);

  http_request_status ('HTTP/1.1 302 Found');
  if (not exists (select 1 from DB.DBA.VSPX_SESSION where VS_SID = sid and VS_REALM = 'wa'))
    {
      auth:
      rhf := WS.WS.PARSE_URI (return_to);
      if (rhf[4] <> '')
	delim := '&';
      else
        delim := '?';
      login := sprintf ('%s?return_to=%U&identity=%U&assoc_handle=%U&trust_root=%U&sreg_required=%U&sreg_optional=%U&policy_url=%U',
	    DB.DBA.wa_link(1, 'login.vspx'), return_to, _identity, coalesce (assoc_handle, ''), trust_root,
	    coalesce (sreg_required, ''), coalesce (sreg_optional, ''), coalesce (policy_url, ''));
      --dbg_obj_print (sprintf ('Location: %s?openid.mode=id_res&openid.user_setup_url=%U\r\n', return_to, login));
      http_header (http_header_get () || sprintf ('Location: %s%sopenid.mode=id_res&openid.user_setup_url=%U\r\n', return_to, delim, login));
    }
  else
    {
      declare ses, ss_key, ss_key_data, inv, sreg, sarr, svec, sregf any;
      declare nickname, email, fullname, dob, gender, postcode, country, lang, timezone any;

      whenever not found goto auth;
      select U_NAME, U_E_MAIL, U_FULL_NAME, WAUI_BIRTHDAY, WAUI_GENDER, WAUI_HCODE, WAUI_HCOUNTRY, WAUI_HTZONE
	 into nickname, email, fullname, dob, gender, postcode, country, timezone
	 from DB.DBA.SYS_USERS, DB.DBA.WA_USER_INFO, DB.DBA.VSPX_SESSION where
	 WAUI_U_ID = U_ID and U_NAME = VS_UID and VS_SID = sid and VS_REALM = 'wa';

      if (dob is not null)
	dob := substring (datestring (dob), 1, 10);

      if (gender = 'male')
        gender := 'M';
      else if (gender = 'female')
        gender := 'F';
      else
        gender := null;

      if (length (country))
        country := (select WC_CODE from DB.DBA.WA_COUNTRY where WC_NAME = country);

      svec := vector (
      			'nickname', nickname,
			'email', email,
			'fullname', fullname,
			'dob', dob,
			'gender', gender,
			'postcode', postcode,
			'country', country,
			'language', 'en',
			'timezone', null -- until fix the format
		    );

      -- XXX should check is assoc_handle is valid !!!
      inv := '';
      if (length (assoc_handle) and exists (select 1 from SERVER_SESSIONS where SS_HANDLE = assoc_handle))
	{
	  select SS_KEY_NAME into ss_key from SERVER_SESSIONS where SS_HANDLE = assoc_handle;
	}
      else
	{
	  if (0 and length (assoc_handle))
	    {
	      inv := sprintf ('&openid.invalidate_handle=%U', assoc_handle);
	    }
	  assoc_handle := sid; --md5 (http_client_ip () || cast (msec_time () as varchar));
	  ss_key := 'OpenID_' || assoc_handle;
	  if (user <> 'OpenID')
  	    set_user_id ('OpenID');
	  --if (xenc_key_exists (ss_key))
	  --xenc_key_remove (ss_key);

	  if (not xenc_key_exists (ss_key))
	    {
	  xenc_key_3DES_rand_create (ss_key);
	    }
	  ss_key_data := xenc_key_serialize (ss_key);
	  --set_user_id ('dba');
	  if (not exists (select 1 from SERVER_SESSIONS where SS_HANDLE = assoc_handle))
	    {
	  insert into SERVER_SESSIONS (SS_HANDLE, SS_KEY_NAME, SS_KEY, SS_KEY_TYPE, SS_EXPIRY)
	      values (assoc_handle, ss_key, ss_key_data, '3DES', dateadd ('hour', 1, now()));
	}
	}

      rhf := WS.WS.PARSE_URI (return_to);
      if (rhf[4] <> '')
	delim := '&';
      else
        delim := '?';

--      dbg_obj_print ('sreg_required',sreg_required);
--      dbg_obj_print ('sreg_optional',sreg_optional);

      sarr := split_and_decode (sreg_required||','||sreg_optional, 0, '\0\0,');
      sreg := '';
      sregf := '';

      ses := string_output ();

      http ('mode:id_res\x0A', ses);
      http (sprintf ('identity:%s\x0A', _identity), ses);
      http (sprintf ('return_to:%s\x0A', return_to), ses);

      foreach (any elm in sarr) do
	{
	  elm := trim(elm);
	  if (length (elm))
	    {
	      declare val any;
	      val := get_keyword (elm, svec, '');
	      if (length (val))
		{
		  sregf := sregf || ',sreg.' || elm;
		  sreg := sreg || '&openid.sreg.'||elm||'='||sprintf ('%U', val);
		  http (sprintf ('sreg.%s:%s\x0A', elm, val), ses);
		}
	    }
	}


      if (user <> 'OpenID')
      set_user_id ('OpenID');

      signature := xenc_hmac_sha1_digest (string_output_string (ses), ss_key);
      if (length (assoc_handle) = 0)
	assoc_handle := '';
      hdr :=  sprintf ('Location: %s%sopenid.mode=id_res&openid.identity=%U&openid.return_to=%U'||
      			'&openid.assoc_handle=%U&openid.signed=%U&openid.sig=%U%s%s\r\n',
	    		return_to, delim, _identity, return_to, coalesce (assoc_handle, ''),
			'mode,identity,return_to'||sregf, signature, inv, sreg);
      http_header (http_header_get () || hdr);
    }
  return '';
};


create procedure checkid_setup
	(
	 in _identity varchar,
	 in assoc_handle varchar := null,
	 in return_to varchar,
	 in trust_root varchar := null,
	 in sid varchar,
	 in sreg_required varchar := null,
	 in sreg_optional varchar := null,
	 in policy_url varchar := null
	 )
{
  declare rhf, delim, login, ss_key any;
  if (not exists (select 1 from DB.DBA.VSPX_SESSION where VS_SID = sid and VS_REALM = 'wa'))
    {
      rhf := WS.WS.PARSE_URI (return_to);
      if (rhf[4] <> '')
	delim := '&';
      else
        delim := '?';
      http_request_status ('HTTP/1.1 302 Found');

      login := sprintf ('%s?return_to=%U&identity=%U&assoc_handle=%U&trust_root=%U&sreg_required=%U&sreg_optional=%U&policy_url=%U',
	    DB.DBA.wa_link(1, 'login.vspx'), return_to, _identity, coalesce (assoc_handle, ''), trust_root,
	    coalesce (sreg_required, ''), coalesce (sreg_optional, ''), coalesce (policy_url, ''));
      http_header (http_header_get () || sprintf ('Location: %s\r\n', login));
      --http_header (http_header_get () || sprintf ('Location: %s%sopenid.mode=cancel\r\n', return_to, delim));
      return '';
    }
  return checkid_immediate (_identity, assoc_handle, return_to, trust_root, sid, 1, sreg_required, sreg_optional, policy_url);
};


create procedure check_authentication
	(
	  in assoc_handle varchar,
	  in sig varchar,
	  in signed varchar,
	  in invalidate_handle varchar := null,
	  in params any := null,
	  in sid varchar
	 )
{
  declare arr, ses, signature any;
  declare key_val, val, ss_key any;

  if (exists (select 1 from SERVER_SESSIONS where SS_HANDLE = assoc_handle))
    {
      select SS_KEY_NAME into ss_key from SERVER_SESSIONS where SS_HANDLE = assoc_handle;
    }
  else
    {
      http ('mode:id_res\x0Ais_valid:false\x0Ainvalidate_handle:'||assoc_handle||'\x0A');
      return '';
    }

  arr := split_and_decode (signed, 0, '\0\0,');
  ses := string_output ();
  foreach (any item in arr) do
    {
      key_val := 'openid.'||item;
      val := get_keyword (key_val, params, '');
      if (key_val = 'openid.mode')
	val := 'id_res';
      http (sprintf ('%s:%s\x0A',item,val), ses);
    }
  if (user <> 'OpenID')
    set_user_id ('OpenID');
  signature := xenc_hmac_sha1_digest (string_output_string (ses), ss_key);

  if (signature = sig)
    http ('mode:id_res\x0Ais_valid:true\x0A');
  else
    http ('mode:id_res\x0Ais_valid:false\x0A');


  return '';
};

create procedure check_signature (in params varchar)
{
  declare nsig, arr, sig, pars, lst, ses, mkey, kname any;

  declare exit handler for sqlstate '*'
    {
      return 0;
    };

  pars := split_and_decode (blob_to_string (params), 0);
  lst := get_keyword ('openid.signed', pars, null);
  mkey := get_keyword ('mac_key', pars, null);
  sig := get_keyword ('openid.sig', pars, null);

  if (lst is null or mkey is null or sig is null)
    return 0;

  ses := string_output ();
  arr := split_and_decode (lst, 0, '\0\0,');
  foreach (any item in arr) do
    {
       declare key_val, val any;
       key_val := 'openid.'||item;
       val := get_keyword (key_val, pars, '');
       http (sprintf ('%s:%s\x0A',item,val), ses);
    }
  kname := xenc_key_RAW_read (null, mkey);
  nsig := xenc_hmac_sha1_digest (string_output_string (ses), kname);
  xenc_key_remove (kname);
  if (nsig = sig)
    return 1;
  return 0;
};

use DB;
