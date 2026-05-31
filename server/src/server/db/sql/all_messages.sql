select m.id, m.user_id, u.username as sender, m.body
from messages m
join users u on u.id = m.user_id
order by m.id;
