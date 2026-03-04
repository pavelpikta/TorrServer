import MovieCreationIcon from '@mui/icons-material/MovieCreation'
import LiveTvIcon from '@mui/icons-material/LiveTv'
import MusicNoteIcon from '@mui/icons-material/MusicNote'
import MoreHorizIcon from '@mui/icons-material/MoreHoriz'

export const TORRENT_CATEGORIES = [
  { key: 'movie', name: 'Movies', icon: <MovieCreationIcon /> },
  { key: 'tv', name: 'Series', icon: <LiveTvIcon /> },
  { key: 'music', name: 'Music', icon: <MusicNoteIcon /> },
  { key: 'other', name: 'Other', icon: <MoreHorizIcon /> },
]
