"""Wire protocol message type constants."""

MAX_ROOMS = 6
MIN_PLAYERS = 2
MAX_PLAYERS = 3
PASSWORD_LENGTH = 15

# Client -> Server
C2S_CLAIM_NAME    = "claim_name"
C2S_LIST_STAGES   = "list_stages"
C2S_LIST_ROOMS    = "list_rooms"
C2S_AUTOCOMPLETE  = "autocomplete"
C2S_CREATE_ROOM   = "create_room"
C2S_JOIN_ROOM     = "join_room"
C2S_LEAVE_ROOM    = "leave_room"
C2S_MOVE          = "move"
C2S_INTERACT      = "interact"
C2S_CHAT          = "chat"

# Server -> Client
S2C_NAME_OK           = "name_ok"
S2C_NAME_FAIL         = "name_failed"
S2C_STAGES_LIST       = "stages_list"
S2C_ROOMS_UPDATE      = "rooms_update"
S2C_AUTOCOMPLETE      = "autocomplete_result"
S2C_ROOM_CREATED      = "room_created"
S2C_ROOM_CREATE_FAIL  = "room_create_failed"
S2C_ROOM_JOINED       = "room_joined"
S2C_ROOM_JOIN_FAIL    = "room_join_failed"
S2C_ROOM_CLOSED       = "room_closed"
S2C_PLAYER_JOINED     = "player_joined"
S2C_PLAYER_LEFT       = "player_left"
S2C_STATE             = "state"
S2C_STAGE_STARTED     = "stage_started"
S2C_STAGE_CLEARED     = "stage_cleared"
S2C_CHAT              = "chat_msg"
S2C_ERROR             = "error"
