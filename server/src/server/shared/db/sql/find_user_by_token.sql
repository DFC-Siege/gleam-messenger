select u.id, u.username
from users u
join sessions s on s.user_id = u.id
where s.token = $1;
