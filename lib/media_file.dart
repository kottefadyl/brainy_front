// Pictures, videos, sound and PDF files are not stored on Vercel's free plan ("mediaFiles" frozen).
// The app checks the name first; the API also checks the file's first bytes.
final _mediaExtensions = RegExp(r'\.(jpe?g|jfif|png|gif|webp|avif|heic|heif|bmp|tiff?|ico|svg|psd|raw|cr2|nef|mp4|m4v|mov|avi|mkv|webm|wmv|flv|3gp|mpe?g|ogv|mp3|m4a|wav|ogg|oga|flac|aac|opus|wma|amr|pdf)$', caseSensitive: false);

bool isMediaFileName(String name) => _mediaExtensions.hasMatch(name.trim());

String mediaRefusedText(bool french) => french
    ? 'Les images, vidéos, sons et fichiers PDF ne sont pas enregistrés sur cet hébergement. Ajoutez plutôt un lien vers le fichier.'
    : 'Pictures, videos, sound and PDF files are not stored on this hosting. Add a link to the file instead.';
