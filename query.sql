set mapred.map.tasks=96;
set mapred.child.java.opts=-Xmx8024m;
set mapred.reduce.tasks=96;
set mapreduce.reduce.java.opts=-Xmx8024m;
set mapreduce.map.java.opts=-Xmx8024m;

drop table ${hiveconf:table}_track_linkages;
create table ${hiveconf:table}_track_linkages as
select intersectx, intersecty, dt, collect_set(track_id) as links, collect_set(velocity) as vels, collect_set(direction) as dirs
from micro_path_tripline_bins_${hiveconf:table}
group by intersectx, intersecty, dt;

drop table ${hiveconf:table}_track_linkages_final;
create table ${hiveconf:table}_track_linkages_final as
select * from ${hiveconf:table}_track_linkages where size(links) > 1;

drop table ${hiveconf:table}_network;
create table ${hiveconf:table}_network
(
intersectX string,
intersextY string,
dt string,
source string,
destination string
);

add file transform.py;

from ${hiveconf:table}_track_linkages_final
insert overwrite table ${hiveconf:table}_network
select transform(intersectX, intersectY, dt, links)
using 'python transform.py'
as intersectX, intersectY, dt, source, destination;

drop table ${hiveconf:table}_dynamic_graph;
create table ${hiveconf:table}_dynamic_graph
(
source string,
destination string,
firstdate string,
lastdate string,
value string
);

add file tag_relationships.py;

from(
select dt, source, destination 
from ${hiveconf:table}_network 
distribute by source, destination
sort by source, destination, dt asc
) m
insert overwrite table ${hiveconf:table}_dynamic_graph
select transform(m.dt, m.source, m.destination)
using 'python tag_relationships.py ${hiveconf:ts}'
as source, destination, firstdate, lastdate, value;


drop table ${hiveconf:table}_network_edges;
create table ${hiveconf:table}_network_edges as
select source as Source, destination as Target, count(*) as Weight
from ${hiveconf:table}_network
group by source, destination;
