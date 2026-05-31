with inserted as (
  insert into messages (user_id, body)
  values ($1, $2)
  returning id, user_id, body
)
select i.id, i.user_id, u.username as sender, i.body
from inserted i
join users u on u.id = i.user_id;
