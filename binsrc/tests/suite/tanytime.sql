



echo both "Anytime timeout test\n";


set result_timeout = 1000;

select fi2 from t1 where delay (fi2 - fi2 + 0.2) = 0;

select fi2 from t1 where  case when mod (fi2, 4) = 1 then delay (fi2 - fi2 + 0.2) else 0 end = 0 option (any order);
select fi2 from t1 where  case when mod (fi2, 4) = 0 then delay (fi2 - fi2 + 0.4) else 0 end = 0 option (any order);

echo both $if $equ $sqlstate S1TAT "PASSED" "***FAILED";
echo both ": Anytime 1\n";

select count (fi2) from t1 where  case when mod (fi2, 4) = 0 then delay (fi2 - fi2 + 0.3) else 0 end = 0 option (any order);
select count (fi2) from t1 where  case when mod (fi2, 4) <> 0 then delay (fi2 - fi2 + 0.3) else 0 end = 0 option (any order);


select count (fi2) from t1 where delay (fi2 - fi2 + 0.2) = 0 option (any order);

echo both $if $equ $sqlstate S1TAT "PASSED" "***FAILED";
echo both ": Anytime 2\n";


-- with dfg
select count (*) from t1 a, t1 b where b.fi2 = 1 + a.fi2 and 0 = delay (b.fi2 - b.fi2 + 0.2) option (loop, order);
-- dfg timeout on coordinator 
select count (*) from t1 a, t1 b where b.fi2 = 1 + a.fi2 and 0 = case when mod (b.fi2, 4) = 0 then delay (b.fi2 - b.fi2 + 0.2) else 0 end option (loop, order);
-- dfg timeout on host 2
select count (*) from t1 a, t1 b where b.fi2 = 1 + a.fi2 and 0 = case when mod (b.fi2, 4) = 1 then delay (b.fi2 - b.fi2 + 0.2) else 0 end option (loop, order);

echo both $if $equ $sqlstate S1TAT "PASSED" "***FAILED";
echo both ": Anytime 3\n";


-- with index order 
select a.fi2, b.fi2 from t1 a, t1 b where b.fi2 = 1 + a.fi2 and 0 = delay (b.fi2 - b.fi2 + 0.2) option (loop, order, any order);

-- with non agg dfg 
select a.fi2, b.fi2 from t1 a, t1 b where b.fi2 = 1 + a.fi2 and 0 = delay (b.fi2 - b.fi2 + 0.2) order by a.fi2 + 1, b.fi2 + 1  option (loop, order);
-- non agg dfg timeout on coordinator 
select a.fi2, b.fi2 from t1 a, t1 b where b.fi2 = 1 + a.fi2 and 0 = case when mod (b.fi2, 4) = 0 then delay (b.fi2 - b.fi2 + 0.2) else 0 end order by a.fi2 + 1, b.fi2 + 1  option (loop, order);

-- non agg dfg timeout on host2
select a.fi2, b.fi2 from t1 a, t1 b where b.fi2 = 1 + a.fi2 and 0 = case when mod (b.fi2, 4) = 1 then delay (b.fi2 - b.fi2 + 0.2) else 0 end order by a.fi2 + 1, b.fi2 + 1  option (loop, order);

echo both $if $equ $sqlstate S1TAT "PASSED" "***FAILED";
echo both ": Anytime 4\n";


-- value qf in index order 
select a.fi2, b.fi2 from t1 a, t1 b where b.fi2 = 1 + a.fi2 and 0 = delay (b.fi2 - b.fi2 + 0.2) order by 1, 2 option (loop, order);
-- value qf, timeout on coordinator 
select a.fi2, b.fi2 from t1 a, t1 b where b.fi2 = 1 + a.fi2 and 0 = case when mod (b.fi2, 4) = 0 then delay (b.fi2 - b.fi2 + 0.2) else 0 end order by 1, 2 option (loop, order);

-- value qf timout host2
select a.fi2, b.fi2 from t1 a, t1 b where b.fi2 = 1 + a.fi2 and 0 = case when mod (b.fi2, 4) = 1 then delay (b.fi2 - b.fi2 + 0.2) else 0 end order by 1, 2 option (loop, order);







-- nested aggregates

-- simple gb + oby

select a.fi2, count (*) from t1 a, t1 b where b.fi2 > a.fi2 and 0 = delay (b.fi2 - b.fi2 + 0.003) group by a.fi2 order by 2 desc  option (order, loop);




-- more counting after the agg 
select dt.fi2, cnt, (select count (*) from t1 c where c.fi2 > dt.fi2 )
from (select a.fi2, count (*) as cnt from t1 a, t1 b where b.fi2 > a.fi2 and 0 = delay (b.fi2 - b.fi2 + 0.003) group by a.fi2 order by 2 desc  option (order, loop)) dt;

echo both $if $equ $sqlstate S1TAT "PASSED" "***FAILED";
echo both ": Anytime 5\n";


-- timeout the counting also.

__dbf_set ('cl_req_batch_size', 10);

select dt.fi2, cnt, (select count (*) from t1 c where c.fi2 > dt.fi2 and 0 = delay (c.fi2 - c.fi2 + 0.002))
from (select a.fi2, count (*) as cnt from t1 a, t1 b where b.fi2 > a.fi2 and 0 = delay (b.fi2 - b.fi2 + 0.003) group by a.fi2 order by 2 desc  option (order, loop)) dt ;


-- fref feeding a code node 
select string2, (select count (*) from t1 b where b.string2 > dt.string2 and 0 = delay (b.fi2 - b.fi2 + 0.001)) from 
(select string2, count (fi2) as cnt from t1 where 0 = delay (fi2 - fi2 + 0.04) group by string2) dt
where cnt = 1
order by 2;

echo both $if $equ $sqlstate S1TAT "PASSED" "***FAILED";
echo both ": Anytime 6\n";


update t1 set fi6 = row_no where 0 = delay (fi2 - fi2 + 0.04);
echo both $if $equ $sqlstate OK "PASSED" "***FAILED";
echo both ": Anytime  update not stopped\n";



create procedure at_upd ()
{
  declare ct int;
  declare exit handler for sqlstate 'S1TAT' {
    if (ct > 0)
      return;
    signal ('BADDD', 'anytime upd in proc stopped');
  };
  set result_timeout = 1000;
  update t1 set fi3 = row_no where 0 = delay (fi2 - fi2 + 0.04);
  ct := (select count (*) from t1 where 0 = delay (fi2 - fi2 + 0.1));
  signal ('BADDD', 'Inm proc, anytime count not stoppped');
}

at_upd ();
-- echo both $if $equ $sqlstate OK "PASSED" "***FAILED";
-- echo both ": Anytime  proc update\n";


