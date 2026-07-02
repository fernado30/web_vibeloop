import fs from "fs";
const path = "C:/Users/EMOTIVA1/Desktop/vibeloop/apps/mobile/lib/features/chat/presentation/chat_screen.dart";
let text = fs.readFileSync(path, "utf8");
text = text.replace(/'\$memberLabel[^\n]*Privado'/, "'memberLabel • Privado'");
text = text.replace(/label: 'Pantallazo'\s*\n\s*iconAsset:/, "label: 'Pantallazo',\n                    iconAsset:");
text = text.replace(/label: 'Invitar'\s*\n\s*iconAsset:/, "label: 'Invitar',\n                    iconAsset:");
text = text.replace(/label: 'Link web'\s*\n\s*iconAsset:/, "label: 'Link web',\n                    iconAsset:");
text = text.replace(/label: 'Fotos'\s*\n\s*iconAsset:/, "label: 'Fotos',\n                    iconAsset:");
text = text.replace('        body: StreamBuilder<List<AnonymousMessageModel>>(        body: StreamBuilder<List<AnonymousMessageModel>>(', '        body: StreamBuilder<List<AnonymousMessageModel>>(');
fs.writeFileSync(path, text, 'utf8');