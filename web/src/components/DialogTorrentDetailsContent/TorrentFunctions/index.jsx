import axios from 'axios'
import { memo } from 'react'
import { playlistTorrHost, torrentsHost, viewedHost } from 'utils/Hosts'
import { CopyToClipboard } from 'react-copy-to-clipboard'
import { Button } from '@mui/material'
import ptt from 'parse-torrent-title'
import { useTranslation } from 'react-i18next'

import { SmallLabel, MainSectionButtonGroup } from './style'
import { SectionSubName } from '../style'

const actionButtonSx = {
  minHeight: 44,
  minWidth: 120,
  '@media (max-width: 480px)': { minHeight: 40, minWidth: 100 },
}

const TorrentFunctions = memo(
  ({ hash, viewedFileList, playableFileList, name, title, setViewedFileList }) => {
    const { t } = useTranslation()
    const latestViewedFileId = viewedFileList?.[viewedFileList?.length - 1]
    const latestViewedFile = playableFileList?.find(({ id }) => id === latestViewedFileId)?.path
    const isOnlyOnePlayableFile = playableFileList?.length === 1
    const latestViewedFileData = latestViewedFile && ptt.parse(latestViewedFile)
    const dropTorrent = () => axios.post(torrentsHost(), { action: 'drop', hash })
    const removeTorrentViews = () =>
      axios.post(viewedHost(), { action: 'rem', hash, file_index: -1 }).then(() => setViewedFileList())
    const fullPlaylistLink = `${playlistTorrHost()}/${encodeURIComponent(name || title || 'file')}.m3u?link=${hash}&m3u`
    const partialPlaylistLink = `${fullPlaylistLink}&fromlast`
    const magnet = `magnet:?xt=urn:btih:${hash}&dn=${encodeURIComponent(name || title)}`

    return (
      <>
        {!isOnlyOnePlayableFile && !!viewedFileList?.length && (
          <>
            <SmallLabel>{t('DownloadPlaylist')}</SmallLabel>
            <SectionSubName mb={10}>
              {t('LatestFilePlayed')}{' '}
              <strong>
                {latestViewedFileData?.title}.
                {latestViewedFileData?.season && (
                  <>
                    {' '}
                    {t('Season')}: {latestViewedFileData?.season}. {t('Episode')}: {latestViewedFileData?.episode}.
                  </>
                )}
              </strong>
            </SectionSubName>

            <MainSectionButtonGroup>
              <a style={{ textDecoration: 'none' }} href={fullPlaylistLink}>
                <Button fullWidth variant='contained' color='primary' size='large' sx={actionButtonSx}>
                  {t('Full')}
                </Button>
              </a>

              <a style={{ textDecoration: 'none' }} href={partialPlaylistLink}>
                <Button fullWidth variant='contained' color='primary' size='large' sx={actionButtonSx}>
                  {t('FromLatestFile')}
                </Button>
              </a>
            </MainSectionButtonGroup>
          </>
        )}
        <SmallLabel mb={10}>{t('TorrentState')}</SmallLabel>
        <MainSectionButtonGroup>
          <Button onClick={() => removeTorrentViews()} variant='contained' color='primary' size='large' sx={actionButtonSx}>
            {t('RemoveViews')}
          </Button>
          <Button onClick={() => dropTorrent()} variant='contained' color='primary' size='large' sx={actionButtonSx}>
            {t('DropTorrent')}
          </Button>
        </MainSectionButtonGroup>
        <SmallLabel mb={10}>{t('Info')}</SmallLabel>
        <MainSectionButtonGroup>
          {(isOnlyOnePlayableFile || !viewedFileList?.length) && (
            <a style={{ textDecoration: 'none' }} href={fullPlaylistLink}>
              <Button fullWidth variant='contained' color='primary' size='large' sx={actionButtonSx}>
                {t('DownloadPlaylist')}
              </Button>
            </a>
          )}
          <CopyToClipboard text={magnet}>
            <Button variant='contained' color='primary' size='large' sx={actionButtonSx}>
              {t('CopyHash')}
            </Button>
          </CopyToClipboard>
        </MainSectionButtonGroup>
      </>
    )
  },
  () => true,
)

export default TorrentFunctions
