module Cocoa::IRC::Commands
  module_function

  InvalidCommandError = Class.new(StandardError)

  COMMAND_TO_SYM_MAP = {
    'PASSWORD' => :password,
    'NICK' => :nick,
    'USER' => :user,
    'OPER' => :oper,
    'MODE' => :mode,
    'SERVICE' => :service,
    'QUIT' => :quit,
    'SQUIT' => :squit,
    'JOIN' => :join,
    'PART' => :part,
    'TOPIC' => :topic,
    'NAMES' => :names,
    'LIST' => :list,
    'INVITE' => :invite,
    'KICK' => :kick,
    'PRIVMSG' => :privmsg,
    'NOTICE' => :notice,
    'MOTD' => :motd,
    'LUSERS' => :lusers,
    'VERSION' => :version,
    'STATS' => :stats,
    'LINKS' => :links,
    'TIME' => :time,
    'CONNECT' => :connect,
    'TRACE' => :trace,
    'ADMIN' => :admin,
    'INFO' => :info,
    'SERVLIST' => :servlist,
    'SQUERY' => :squery,
    'WHO' => :who,
    'WHOIS' => :whois,
    'WHOWAS' => :whowas,
    'KILL' => :kill,
    'PING' => :ping,
    'PONG' => :pong,
    'ERROR' => :error,
    'AWAY' => :away,
    'REHASH' => :rehash,
    'DIE' => :die,
    'RESTART' => :restart,
    'SUMMON' => :summon,
    'USERS' => :users,
    'WALLOPS' => :wallops,
    'USERHOST' => :userhost,
    'ISON' => :ison,

    '001' => :rpl_welcome,
    '002' => :rpl_yourhost,
    '003' => :rpl_created,
    '004' => :rpl_myinfo,
    '005' => :rpl_bounce,
    '302' => :rpl_userhost,
    '303' => :rpl_ison,
    '301' => :rpl_away,
    '305' => :rpl_unaway,
    '306' => :rpl_nowaway,
    '311' => :rpl_whoisuser,
    '312' => :rpl_whoisserver,
    '313' => :rpl_whoisoperator,
    '317' => :rpl_whoisidle,
    '318' => :rpl_endofwhois,
    '319' => :rpl_whoischannels,
    '314' => :rpl_whowasuser,
    '369' => :rpl_endofwhowas,
    '321' => :rpl_liststart,
    '322' => :rpl_list,
    '323' => :rpl_listend,
    '325' => :rpl_uniqopis,
    '324' => :rpl_channelmodeis,
    '331' => :rpl_notopic,
    '332' => :rpl_topic,
    '341' => :rpl_inviting,
    '342' => :rpl_summoning,
    '346' => :rpl_invitelist,
    '347' => :rpl_endofinvitelist,
    '348' => :rpl_exceptlist,
    '349' => :rpl_endofexceptlist,
    '351' => :rpl_version,
    '352' => :rpl_whoreply,
    '315' => :rpl_endofwho,
    '353' => :rpl_namreply,
    '366' => :rpl_endofnames,
    '364' => :rpl_links,
    '365' => :rpl_endoflinks,
    '367' => :rpl_banlist,
    '368' => :rpl_endofbanlist,
    '371' => :rpl_info,
    '374' => :rpl_endofinfo,
    '375' => :rpl_motdstart,
    '372' => :rpl_motd,
    '376' => :rpl_endofmotd,
    '381' => :rpl_youreoper,
    '382' => :rpl_rehashing,
    '383' => :rpl_youreservice,
    '391' => :rpl_time,
    '392' => :rpl_usersstart,
    '393' => :rpl_users,
    '394' => :rpl_endofusers,
    '395' => :rpl_nousers,
    '200' => :rpl_tracelink,
    '201' => :rpl_traceconnecting,
    '202' => :rpl_tracehandshake,
    '203' => :rpl_traceunknown,
    '204' => :rpl_traceoperator,
    '205' => :rpl_traceuser,
    '206' => :rpl_traceserver,
    '207' => :rpl_traceservice,
    '208' => :rpl_tracenewtype,
    '209' => :rpl_traceclass,
    '210' => :rpl_tracereconnect,
    '261' => :rpl_tracelog,
    '262' => :rpl_traceend,
    '211' => :rpl_statslinkinfo,
    '212' => :rpl_statscommands,
    '219' => :rpl_endofstats,
    '242' => :rpl_statsuptime,
    '243' => :rpl_statsoline,
    '221' => :rpl_umodeis,
    '234' => :rpl_servlist,
    '235' => :rpl_servlistend,
    '251' => :rpl_luserclient,
    '252' => :rpl_luserop,
    '253' => :rpl_luserunknown,
    '254' => :rpl_luserchannels,
    '255' => :rpl_luserme,
    '256' => :rpl_adminme,
    '257' => :rpl_adminloc1,
    '258' => :rpl_adminloc2,
    '259' => :rpl_adminemail,
    '263' => :rpl_tryagain,
    '401' => :err_nosuchnick,
    '402' => :err_nosuchserver,
    '403' => :err_nosuchchannel,
    '404' => :err_cannotsendtochan,
    '405' => :err_toomanychannels,
    '406' => :err_wasnosuchnick,
    '407' => :err_toomanytargets,
    '408' => :err_nosuchservice,
    '409' => :err_noorigin,
    '411' => :err_norecipient,
    '412' => :err_notexttosend,
    '413' => :err_notoplevel,
    '414' => :err_wildtoplevel,
    '415' => :err_badmask,
    '421' => :err_unknowncommand,
    '422' => :err_nomotd,
    '423' => :err_noadmininfo,
    '424' => :err_fileerror,
    '431' => :err_nonicknamegiven,
    '432' => :err_erroneusnickname,
    '433' => :err_nicknameinuse,
    '436' => :err_nickcollision,
    '437' => :err_unavailresource,
    '441' => :err_usernotinchannel,
    '442' => :err_notonchannel,
    '443' => :err_useronchannel,
    '444' => :err_nologin,
    '445' => :err_summondisabled,
    '446' => :err_usersdisabled,
    '451' => :err_notregistered,
    '461' => :err_needmoreparams,
    '462' => :err_alreadyregistred,
    '463' => :err_nopermforhost,
    '464' => :err_passwdmismatch,
    '465' => :err_yourebannedcreep,
    '466' => :err_youwillbebanned,
    '467' => :err_keyset,
    '471' => :err_channelisfull,
    '472' => :err_unknownmode,
    '473' => :err_inviteonlychan,
    '474' => :err_bannedfromchan,
    '475' => :err_badchannelkey,
    '476' => :err_badchanmask,
    '477' => :err_nochanmodes,
    '478' => :err_banlistfull,
    '481' => :err_noprivileges,
    '482' => :err_chanoprivsneeded,
    '483' => :err_cantkillserver,
    '484' => :err_restricted,
    '485' => :err_uniqopprivsneeded,
    '491' => :err_nooperhost,
    '501' => :err_umodeunknownflag,
    '502' => :err_usersdontmatch,
    '231' => :rpl_serviceinfo,
    '232' => :rpl_endofservices,
    '233' => :rpl_service,
    '300' => :rpl_none,
    '316' => :rpl_whoischanop,
    '361' => :rpl_killdone,
    '362' => :rpl_closing,
    '363' => :rpl_closeend,
    '373' => :rpl_infostart,
    '384' => :rpl_myportis,
    '213' => :rpl_statscline,
    '214' => :rpl_statsnline,
    '215' => :rpl_statsiline,
    '216' => :rpl_statskline,
    '217' => :rpl_statsqline,
    '218' => :rpl_statsyline,
    '240' => :rpl_statsvline,
    '241' => :rpl_statslline,
    '244' => :rpl_statshline,
    '244' => :rpl_statssline,
    '246' => :rpl_statsping,
    '247' => :rpl_statsbline,
    '250' => :rpl_statsdline,
    '492' => :err_noservicehost
  }

  SYM_TO_COMMAND_MAP = COMMAND_TO_SYM_MAP.invert

  def to_sym(cmd)
    return COMMAND_TO_SYM_MAP[cmd] if COMMAND_TO_SYM_MAP.key? cmd
    fail InvalidCommandError, cmd
  end

  def from_sym(sym)
    return SYM_TO_COMMAND_MAP[sym] if SYM_TO_COMMAND_MAP.key? sym
    fail InvalidCommandError, sym
  end
end
