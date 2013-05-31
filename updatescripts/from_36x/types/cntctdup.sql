SELECT dropIfExists('FUNCTION', 'cntctdups(text, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean)');
SELECT dropIfExists('TYPE', 'cntctdup');

CREATE TYPE cntctdup AS
(
    cntct_id integer,
    cntct_crmacct_id integer,
    cntct_addr_id integer,
    cntct_first_name text,
    cntct_last_name text,
    cntct_honorific text,
    cntct_initials text,
    cntct_active boolean,
    cntct_phone text,
    cntct_phone2 text,
    cntct_fax text,
    cntct_email text,
    cntct_webaddr text,
    cntct_notes text,
    cntct_title text,
    cntct_number text,
    cntct_middle text,
    cntct_suffix text,
    cntct_owner_username text,
    cntct_name text,
    crmacct_number text, 
    crmacct_name text,
    addr_id integer,
    addr_active boolean,
    addr_line1 text,
    addr_line2 text,
    addr_line3 text,
    addr_city text,
    addr_state text,
    addr_postalcode text,
    addr_country text,
    addr_notes text,
    addr_number text,
    cntctdup_level integer
);