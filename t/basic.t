use t::Helper;
use WebIrc::Chat;

is WebIrc::Chat::PING_INTERVAL, 30, 'send ping to client every 30 second';

done_testing;
