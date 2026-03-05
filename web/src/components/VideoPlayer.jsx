import {
  Box,
  CircularProgress,
  DialogContent,
  DialogTitle,
  IconButton,
  Menu,
  MenuItem,
  Slider,
  Tooltip,
  Typography,
  useMediaQuery,
} from '@mui/material'
import { styled } from '@mui/material/styles'
import CloseIcon from '@mui/icons-material/Close'
import Forward10Icon from '@mui/icons-material/Forward10'
import FullscreenIcon from '@mui/icons-material/Fullscreen'
import FullscreenExitIcon from '@mui/icons-material/FullscreenExit'
import GetAppIcon from '@mui/icons-material/GetApp'
import PauseIcon from '@mui/icons-material/Pause'
import PictureInPictureIcon from '@mui/icons-material/PictureInPicture'
import PlayArrowIcon from '@mui/icons-material/PlayArrow'
import Replay10Icon from '@mui/icons-material/Replay10'
import SpeedIcon from '@mui/icons-material/Speed'
import VolumeOffIcon from '@mui/icons-material/VolumeOff'
import VolumeUpIcon from '@mui/icons-material/VolumeUp'
import { useCallback, useEffect, useRef, useState } from 'react'
import { StyledDialog } from 'style/CustomMaterialUiStyles'
import { useTranslation } from 'react-i18next'

import { StyledButton } from './TorrentCard/style'

function getMimeType(url) {
  const ext = url.split('?')[0].split('.').pop().toLowerCase()
  switch (ext) {
    case 'mp4':
      return 'video/mp4'
    case 'ogg':
    case 'ogv':
      return 'video/ogg'
    case 'webm':
      return 'video/webm'
    default:
      return ''
  }
}

const PrettoSlider = styled(Slider)(({ theme }) => ({
  color: '#00a572',
  height: 6,
  [theme.breakpoints.down('sm')]: {
    height: 0,
  },
  '& .MuiSlider-thumb': {
    height: 18,
    width: 18,
    backgroundColor: '#fff',
    border: '2px solid currentColor',
    marginTop: -6,
    marginLeft: -12,
    [theme.breakpoints.down('sm')]: {
      height: 15,
      width: 15,
      marginTop: -5,
      marginLeft: -7,
    },
  },
  '& .MuiSlider-track': {
    height: 6,
    borderRadius: 4,
    [theme.breakpoints.down('sm')]: {
      height: 5,
    },
  },
  '& .MuiSlider-rail': {
    height: 6,
    borderRadius: 4,
    [theme.breakpoints.down('sm')]: {
      height: 6,
    },
  },
}))

const VideoWrapper = styled(Box)(() => ({
  position: 'relative',
  width: '100%',
  backgroundColor: '#000',
  overflow: 'hidden',
  '&:hover [data-video-controls]': {
    opacity: 1,
  },
}))

const StyledVideo = styled('video')(({ theme }) => ({
  width: '100%',
  display: 'block',
  cursor: 'pointer',
  [theme.breakpoints.down('sm')]: {
    height: '94.5vh',
    width: '100vw',
    objectFit: 'contain',
  },
}))

const LoadingOverlay = styled(Box)(() => ({
  position: 'absolute',
  top: 0,
  left: 0,
  width: '100%',
  height: '100%',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  backgroundColor: 'rgba(0,0,0,0.6)',
  zIndex: 4,
}))

const CentralControl = styled(IconButton)(({ theme }) => ({
  position: 'absolute',
  top: '50%',
  left: '50%',
  transform: 'translate(-50%, -50%)',
  borderRadius: '50%',
  padding: theme.spacing(1),
  backgroundColor: 'rgba(0,0,0,0.5)',
  opacity: 0,
  transition: 'opacity 200ms',
  zIndex: 3,
  color: '#fff',
  pointerEvents: 'none',
  animation: 'pulse 0.6s ease-out',
  '@keyframes pulse': {
    '0%': { transform: 'translate(-50%, -50%) scale(0.5)', opacity: 0 },
    '50%': { transform: 'translate(-50%, -50%) scale(1)', opacity: 1 },
    '100%': { transform: 'translate(-50%, -50%) scale(1.3)', opacity: 0 },
  },
}))

const Controls = styled(Box)(({ theme }) => ({
  position: 'absolute',
  bottom: 0,
  left: 0,
  width: '100%',
  background: 'linear-gradient(to top, rgba(0,0,0,0.8), transparent)',
  padding: theme.spacing(0, 3, 2, 3),
  transition: 'opacity 200ms',
  opacity: 0,
  display: 'flex',
  flexDirection: 'column',
  gap: theme.spacing(0.5),
  zIndex: 3,
  pointerEvents: 'auto',
  [theme.breakpoints.down('sm')]: {
    opacity: 1,
    padding: theme.spacing(0, 1, 2, 1),
    gap: theme.spacing(0),
    background: 'linear-gradient(to top, rgba(0,0,0,0.95), transparent)',
  },
}))

const TimeRow = styled(Box)(({ theme }) => ({
  color: '#fff',
  paddingLeft: theme.spacing(2),
  [theme.breakpoints.down('sm')]: {
    paddingLeft: theme.spacing(1),
    fontSize: 9,
  },
}))

const SliderStyled = styled(Slider)(() => ({
  color: '#00e68a',
  '& .MuiSlider-thumb': { backgroundColor: '#00e68a' },
  '& .MuiSlider-track': { borderRadius: 2 },
}))

const ControlRow = styled(Box)(() => ({
  display: 'flex',
  alignItems: 'center',
}))

const IconButtonStyled = styled(IconButton)(({ theme }) => ({
  color: '#fff',
  padding: 12,
  '&:hover': { backgroundColor: 'rgba(255,255,255,0.1)' },
  [theme.breakpoints.down('sm')]: {
    padding: 10,
  },
}))

// Helper function to format seconds to HH:MM:SS
const formatTime = seconds => {
  if (!isFinite(seconds)) return '00:00:00'
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  const s = Math.floor(seconds % 60)
  const hh = h.toString().padStart(2, '0')
  const mm = m.toString().padStart(2, '0')
  const ss = s.toString().padStart(2, '0')
  return `${hh}:${mm}:${ss}`
}

const VideoPlayer = ({ videoSrc, captionSrc = '', title, onNotSupported }) => {
  const isMobile = useMediaQuery('@media (max-width:930px)')
  const videoRef = useRef(null)
  const { t } = useTranslation()
  const [open, setOpen] = useState(false)
  const [loading, setLoading] = useState(true)
  const [playing, setPlaying] = useState(false)
  const [currentTime, setCurrentTime] = useState(0)
  const [duration, setDuration] = useState(0)
  const [muted, setMuted] = useState(false)
  const [volume, setVolume] = useState(1)
  const [fullscreen, setFullscreen] = useState(false)
  const [anchorEl, setAnchorEl] = useState(null)
  const [speed, setSpeed] = useState(1)

  useEffect(() => {
    const vid = document.createElement('video')
    if (!vid.canPlayType(getMimeType(videoSrc))) onNotSupported()
  }, [videoSrc, onNotSupported])

  const handlePlayPause = useCallback(() => {
    const video = videoRef.current
    if (!video) return
    video.paused ? video.play() : video.pause()
  }, [])

  const togglePlay = () => setPlaying(p => !p)
  const handleTimeUpdate = () => setCurrentTime(videoRef.current.currentTime)
  const handleLoaded = () => {
    setDuration(videoRef.current.duration)
    setLoading(false)
  }
  const handleSeek = (_, val) => {
    videoRef.current.currentTime = val
    handleTimeUpdate()
  }
  const handleVolume = (_, val) => {
    const v = val / 100
    videoRef.current.volume = v
    setVolume(v)
    setMuted(v === 0)
  }
  const toggleMute = () => {
    videoRef.current.muted = !muted
    setMuted(m => !m)
  }

  const skip = useCallback(
    secs => {
      const video = videoRef.current
      if (!video) return
      const target = Math.min(Math.max(video.currentTime + secs, 0), duration)
      video.currentTime = target
      setCurrentTime(target)
    },
    [duration],
  )

  const enterFull = () => videoRef.current.requestFullscreen()
  const exitFull = () => document.exitFullscreen()

  useEffect(() => {
    const onFull = () => setFullscreen(!!document.fullscreenElement)
    document.addEventListener('fullscreenchange', onFull)
    return () => document.removeEventListener('fullscreenchange', onFull)
  }, [])

  const openSpeedMenu = e => setAnchorEl(e.currentTarget)
  const closeSpeedMenu = () => setAnchorEl(null)
  const changeSpeed = val => {
    videoRef.current.playbackRate = val
    setSpeed(val)
    closeSpeedMenu()
  }
  const downloadVideo = () => {
    const a = document.createElement('a')
    a.href = videoSrc
    a.download = ''
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
  }

  const handleKey = useCallback(
    e => {
      if (!open) return
      switch (e.key) {
        case ' ':
          e.preventDefault()
          handlePlayPause()
          break
        case 'ArrowRight':
          e.preventDefault()
          skip(10)
          break
        case 'ArrowLeft':
          e.preventDefault()
          skip(-10)
          break
        default:
          break
      }
    },
    [open, handlePlayPause, skip],
  )
  useEffect(() => {
    document.addEventListener('keydown', handleKey)
    return () => document.removeEventListener('keydown', handleKey)
  }, [handleKey])

  return (
    <>
      <StyledButton onClick={() => setOpen(true)}>
        <PlayArrowIcon />
        <span>{t('Play')}</span>
      </StyledButton>
      <StyledDialog
        open={open}
        onClose={() => setOpen(false)}
        maxWidth='lg'
        fullWidth
        fullScreen={isMobile}
        slotProps={{
          paper: {
            sx: { backgroundColor: '#fff', borderRadius: 1 },
          },
        }}
      >
        <DialogTitle
          sx={theme => ({
            backgroundColor: '#00a572',
            color: '#fff',
            padding: theme.spacing(1, 2),
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
          })}
        >
          <Typography variant='h6' noWrap>
            {title || 'Video Player'}
          </Typography>
          <IconButtonStyled size='medium' onClick={() => setOpen(false)}>
            <CloseIcon fontSize='medium' />
          </IconButtonStyled>
        </DialogTitle>
        <DialogContent style={{ padding: 0 }}>
          <VideoWrapper onClick={handlePlayPause} style={isMobile ? { minHeight: 240 } : {}} data-video-controls>
            <StyledVideo
              autoPlay
              ref={videoRef}
              src={videoSrc}
              onTimeUpdate={handleTimeUpdate}
              onLoadedMetadata={handleLoaded}
              onPlay={togglePlay}
              onPause={togglePlay}
            >
              <track kind='captions' srcLang='en' label='English captions' src={captionSrc} default />
            </StyledVideo>
            {loading && (
              <LoadingOverlay>
                <CircularProgress fontSize='medium' />
              </LoadingOverlay>
            )}
            <CentralControl
              size='medium'
              data-video-controls
              style={{
                opacity: playing ? 0 : 1,
              }}
            >
              <PlayArrowIcon fontSize='medium' />
            </CentralControl>
            <Controls onClick={e => e.stopPropagation()} data-video-controls>
              {isMobile && (
                <TimeRow>
                  <Typography variant='body2'>
                    {formatTime(currentTime)} / {formatTime(duration)}
                  </Typography>
                </TimeRow>
              )}
              <PrettoSlider value={currentTime} max={duration} onChange={handleSeek} size='medium' />
              <ControlRow>
                <Tooltip title={playing ? t('Pause') : t('Play')}>
                  <IconButtonStyled size='medium' onClick={handlePlayPause}>
                    {playing ? <PauseIcon fontSize='medium' /> : <PlayArrowIcon fontSize='medium' />}
                  </IconButtonStyled>
                </Tooltip>
                <Tooltip title={t('Rewind-10-Sec')}>
                  <IconButtonStyled
                    size='medium'
                    onClick={e => {
                      e.stopPropagation()
                      skip(-10)
                    }}
                  >
                    <Replay10Icon fontSize='medium' />
                  </IconButtonStyled>
                </Tooltip>

                <Tooltip title={t('Forward-10-Sec')}>
                  <IconButtonStyled
                    size='medium'
                    onClick={e => {
                      e.stopPropagation()
                      skip(10)
                    }}
                  >
                    <Forward10Icon fontSize='medium' />
                  </IconButtonStyled>
                </Tooltip>
                <Tooltip title={muted ? t('Unmute') : t('Mute')}>
                  <IconButtonStyled size='medium' onClick={toggleMute}>
                    {muted ? <VolumeOffIcon fontSize='medium' /> : <VolumeUpIcon fontSize='medium' />}
                  </IconButtonStyled>
                </Tooltip>
                {!isMobile && (
                  <SliderStyled value={volume * 100} onChange={handleVolume} size='medium' style={{ width: 70 }} />
                )}
                {!isMobile && (
                  <TimeRow>
                    <Typography variant='body2'>
                      {formatTime(currentTime)} / {formatTime(duration)}
                    </Typography>
                  </TimeRow>
                )}
                <Box flexGrow={1} />
                <Tooltip title={t('Speed')}>
                  <IconButtonStyled size='medium' onClick={openSpeedMenu}>
                    <SpeedIcon fontSize='medium' />
                  </IconButtonStyled>
                </Tooltip>
                <Menu
                  anchorEl={anchorEl}
                  open={Boolean(anchorEl)}
                  onClose={closeSpeedMenu}
                  slotProps={{ paper: { sx: { minWidth: 100 } } }}
                >
                  {[0.5, 1, 1.5, 2].map(r => (
                    <MenuItem key={r} selected={r === speed} onClick={() => changeSpeed(r)}>
                      {r}x
                    </MenuItem>
                  ))}
                </Menu>
                <Tooltip title={t('PIP')}>
                  <IconButtonStyled size='medium' onClick={() => videoRef.current.requestPictureInPicture()}>
                    <PictureInPictureIcon fontSize='medium' />
                  </IconButtonStyled>
                </Tooltip>

                <Tooltip title={t('Download')}>
                  <IconButtonStyled size='medium' onClick={downloadVideo}>
                    <GetAppIcon fontSize='medium' />
                  </IconButtonStyled>
                </Tooltip>

                <Tooltip title={fullscreen ? t('ExitFullscreen') : t('Fullscreen')}>
                  <IconButtonStyled size='medium' onClick={fullscreen ? exitFull : enterFull}>
                    {fullscreen ? <FullscreenExitIcon fontSize='medium' /> : <FullscreenIcon fontSize='medium' />}
                  </IconButtonStyled>
                </Tooltip>
              </ControlRow>
            </Controls>
          </VideoWrapper>
        </DialogContent>
      </StyledDialog>
    </>
  )
}

export default VideoPlayer
