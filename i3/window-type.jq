# Window type from an i3 container: image / pdf / video / audio / terminal / browser / other.
# Shared by window-actions-menu.sh and popup-arrange.sh: jq -L ~/.config/i3 'include "window-type"; ...'
def window_type:
  (.window_properties.class // "") as $c | (.window_properties.instance // "") as $i
  | if   ($c | test("^(Eog|EogPopup|Nsxiv)$"; "i")) or $i == "NsxivPopup" then "image"
    elif  $c | test("^(Evince|EvincePopup)$"; "i")                        then "pdf"
    elif ($c | test("^(vlc|mpv)$"; "i")) or $i == "VlcPopup"             then "video"
    elif  $i == "AudioPopup"                                              then "audio"
    elif  $c | test("^(Alacritty|AlacrittyPopup|kitty|Gnome-terminal|xterm)$"; "i") then "terminal"
    elif  $c | test("chrom|firefox|brave"; "i")                          then "browser"
    else "other" end;

# Display order of the types
def window_type_rank: {image: 0, pdf: 1, video: 2, audio: 3, terminal: 4, browser: 5, other: 6}[window_type];
