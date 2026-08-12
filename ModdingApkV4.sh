#!/data/data/com.termux/files/usr/bin/bash

# Matikan Job Control bawaan bash agar tidak mengacak tampilan progress bar
set +m

# =============================================================
# COLOR DEFINITIONS
# =============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

# =============================================================
# DEPENDENCY CHECK & VISUAL AUTO-INSTALL VIA PKG (TERMUX)
# =============================================================
clear
echo -e "${CYAN}=======================================================${RESET}"
echo -e "${CYAN}          MEMERIKSA & MENYIAPKAN BAHAN SYSTEM          ${RESET}"
echo -e "${CYAN}=======================================================${RESET}"

DEPENDENCIES=("apktool" "zipalign" "keytool" "aapt" "python3" "stat" "sleep" "printf" "awk" "sed" "grep" "du" "tr" "java" "unzip" "zip")
MISSING_DEPS=()

for tool in "${DEPENDENCIES[@]}"; do
    if command -v "$tool" &> /dev/null; then
        echo -e "  ${GREEN}[✓] $tool${RESET} (Sudah ter-install)"
    else
        echo -e "  ${RED}[✗] $tool${RESET} (Belum ada)"
        MISSING_DEPS+=("$tool")
    fi
done

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    echo -e "\n${YELLOW}[!] Meng-install bahan/paket yang kurang via pkg...${RESET}"
    pkg update -y -o Dpkg::Options::="--force-confnew" && pkg upgrade -y -o Dpkg::Options::="--force-confnew" > /dev/null 2>&1
    pkg install -y android-tools openjdk-17 apktool python termux-api coreutils findutils grep sed gawk unzip zip > /dev/null 2>&1
    
    echo -e "\n${CYAN}[*] Mengecek ulang hasil instalasi...${RESET}"
    RECHECK_FAILED=0
    for tool in "${MISSING_DEPS[@]}"; do
        if command -v "$tool" &> /dev/null; then
            echo -e "  ${GREEN}[✓] $tool${RESET} (Berhasil di-install)"
        else
            echo -e "  ${RED}[✗] $tool${RESET} (Gagal di-install)"
            RECHECK_FAILED=1
        fi
    done
    
    if [ $RECHECK_FAILED -eq 1 ]; then
        echo -e "\n${RED}[!] Beberapa dependensi gagal ter-install. Silakan cek koneksi/repo Termux kamu.${RESET}"
        exit 1
    fi
fi

echo -e "\n${GREEN}[✓] Semua bahan dan dependensi lengkap & siap digunakan!${RESET}"
sleep 1.5

# =============================================================
# VISUAL PROGRESS BAR & ANIMATION
# =============================================================
show_progress() {
    local title="$1"
    local pid="$2"
    echo -e "${CYAN}[*] $title...${RESET}"
    local spin='-\|/'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i + 1) % 4 ))
        printf "\r    [%c] Memproses..." "${spin:$i:1}"
        sleep 0.15
    done
    printf "\r    [✓] Selesai!                     \n"
}

show_dir_progress() {
    local title="$1"
    local target_dir="$2"
    local pid="$3"
    local width=30

    echo -e "${CYAN}[*] $title${RESET}"
    local i=1
    while kill -0 "$pid" 2>/dev/null; do
        local current_kb=0
        if [ -d "$target_dir" ]; then
            current_kb=$(du -s "$target_dir" 2>/dev/null | awk '{print $1}')
            [ -z "$current_kb" ] && current_kb=0
        fi
        local current_mb=$(python3 -c "print(f'{$current_kb / 1024:.2f}')" 2>/dev/null || echo "0.00")
        local pos=$(( (i % width) + 1 ))
        local arrows=""
        if [ $pos -lt $width ]; then
            arrows=$(printf '%*s' "$((pos-1))" '' | tr ' ' '=')">"
        else
            arrows=$(printf '%*s' "$pos" '' | tr ' ' '=')
        fi
        printf "\r    [%-30s] Terekstraksi: %s MB" "$arrows" "$current_mb"
        sleep 0.2
        ((i++))
    done
    local final_kb=0
    if [ -d "$target_dir" ]; then
        final_kb=$(du -s "$target_dir" 2>/dev/null | awk '{print $1}')
        [ -z "$final_kb" ] && final_kb=0
    fi
    local final_mb=$(python3 -c "print(f'{$final_kb / 1024:.2f}')" 2>/dev/null || echo "0.00")
    printf "\r    [%-30s] Total: %s MB | Selesai!      \n" "$(printf '%*s' "$width" '' | tr ' ' '=')" "$final_mb"
}

show_compress_progress() {
    local title="$1"
    local target_file="$2"
    local pid="$3"
    local width=30

    echo -e "${CYAN}[*] $title${RESET}"
    local i=1
    while kill -0 "$pid" 2>/dev/null; do
        local current_bytes=0
        if [ -f "$target_file" ]; then
            current_bytes=$(stat -c%s "$target_file" 2>/dev/null || stat -f%z "$target_file" 2>/dev/null || echo 0)
        fi
        local current_mb=$(python3 -c "print(f'{$current_bytes / 1048576:.2f}')" 2>/dev/null || echo "0.00")
        local pos=$(( (i % width) + 1 ))
        local arrows=""
        if [ $pos -lt $width ]; then
            arrows=$(printf '%*s' "$((pos-1))" '' | tr ' ' '=')">"
        else
            arrows=$(printf '%*s' "$pos" '' | tr ' ' '=')
        fi
        printf "\r    [%-30s] Memproses File: %s MB" "$arrows" "$current_mb"
        sleep 0.2
        ((i++))
    done
    local final_bytes=0
    if [ -f "$target_file" ]; then
        final_bytes=$(stat -c%s "$target_file" 2>/dev/null || stat -f%z "$target_file" 2>/dev/null || echo 0)
    fi
    local final_mb=$(python3 -c "print(f'{$final_bytes / 1048576:.2f}')" 2>/dev/null || echo "0.00")
    printf "\r    [%-30s] Total: %s MB | Selesai!      \n" "$(printf '%*s' "$width" '' | tr ' ' '=')" "$final_mb"
}

# =============================================================
# MAIN LOOP (LANJUT KE APK LAIN ATAU KELUAR)
# =============================================================
while true; do
    clear
    # =============================================================
    # INPUT FILE & SPLIT APK EXTRACTOR & DYNAMIC SELECTOR
    # =============================================================
    echo -e "${CYAN}=======================================================${RESET}"
    echo -e "${CYAN}   ADVANCED SPLIT APK EXTRACTOR & SELECTOR MODULE      ${RESET}"
    echo -e "${CYAN}=======================================================${RESET}"

    read -p "Masukkan path file (APK / APKS / XAPK / APKM): " INPUT_PATH
    INPUT_PATH=$(echo "$INPUT_PATH" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

    if [ ! -f "$INPUT_PATH" ]; then
        echo -e "${RED}[!] File tidak ditemukan di path: $INPUT_PATH${RESET}"
        read -p "Tekan Enter untuk mencoba lagi..."
        continue
    fi

    EXT="${INPUT_PATH##*.}"
    EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')

    TEMP_SPLIT_DIR="split_extracted_temp"
    rm -rf "$TEMP_SPLIT_DIR"
    mkdir -p "$TEMP_SPLIT_DIR"

    APK_FILENAME=$(basename "$INPUT_PATH")
    RAW_NAME="${APK_FILENAME%.*}"

    TARGET_APK=""

    if [ "$EXT_LOWER" = "apks" ] || [ "$EXT_LOWER" = "xapk" ] || [ "$EXT_LOWER" = "apkm" ]; then
        echo -e "\n${CYAN}[*] Mendeteksi file $EXT_LOWER, mengekstrak komponen split APK...${RESET}"
        unzip -q "$INPUT_PATH" -d "$TEMP_SPLIT_DIR" 2>/dev/null

        mapfile -t ALL_SPLIT_FILES < <(find "$TEMP_SPLIT_DIR" -type f -name "*.apk")

        if [ ${#ALL_SPLIT_FILES[@]} -eq 0 ]; then
            echo -e "${RED}[!] Tidak ditemukan file APK di dalam arsip $EXT_LOWER.${RESET}"
            rm -rf "$TEMP_SPLIT_DIR"
            read -p "Tekan Enter untuk mencoba lagi..."
            continue
        fi

        BASE_APK=""
        LARGEST_SIZE=0

        for f in "${ALL_SPLIT_FILES[@]}"; do
            bname=$(basename "$f")
            fsize=$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null || echo 0)
            
            if [[ "$bname" =~ ^base\.apk$ || "$bname" =~ master || "$bname" =~ bundle ]]; then
                if [ "$fsize" -gt "$LARGEST_SIZE" ]; then
                    LARGEST_SIZE=$fsize
                    BASE_APK="$f"
                fi
            fi
        done

        if [ -z "$BASE_APK" ]; then
            for f in "${ALL_SPLIT_FILES[@]}"; do
                fsize=$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null || echo 0)
                if [ "$fsize" -gt "$LARGEST_SIZE" ]; then
                    LARGEST_SIZE=$fsize
                    BASE_APK="$f"
                fi
            done
        fi

        echo -e "\n${GREEN}[✓] Daftar Komponen Split & Modul yang Ditemukan di dalam $EXT_LOWER:${RESET}"
        echo -e "${YELLOW}-------------------------------------------------------${RESET}"
        
        INDEX=1
        declare -A SPLIT_MAP
        
        for f in "${ALL_SPLIT_FILES[@]}"; do
            bname=$(basename "$f")
            fsize=$(du -h "$f" | cut -f1)
            if [ "$f" = "$BASE_APK" ]; then
                echo -e "  ${CYAN}[$INDEX]${RESET} Base APK Utama -> $bname (${fsize})"
            else
                echo -e "  ${GREEN}[$INDEX]${RESET} Split / Resource / Arsitektur -> $bname (${fsize})"
            fi
            SPLIT_MAP[$INDEX]="$f"
            ((INDEX++))
        done
        echo -e "${YELLOW}-------------------------------------------------------${RESET}"

        echo -e "\n${CYAN}Silakan pilih nomor komponen tambahan yang ingin digabungkan.${RESET}"
        echo -e "Contoh cara pilih: Ketik ${YELLOW}2 3 5${RESET} (dipisah spasi) atau tekan Enter untuk lewat."
        read -p "Masukkan pilihan nomor komponen: " CHOSEN_SPLITS

        TARGET_APK="$BASE_APK"

        if [ -n "$CHOSEN_SPLITS" ]; then
            MERGE_TEMP="merged_split_temp"
            rm -rf "$MERGE_TEMP"
            mkdir -p "$MERGE_TEMP"
            
            unzip -q "$BASE_APK" -d "$MERGE_TEMP" 2>/dev/null

            for num in $CHOSEN_SPLITS; do
                selected_file="${SPLIT_MAP[$num]}"
                if [ -n "$selected_file" ] && [ "$selected_file" != "$BASE_APK" ]; then
                    echo -e "${YELLOW}[*] Menggabungkan komponen: $(basename "$selected_file")${RESET}"
                    unzip -qo "$selected_file" -d "$MERGE_TEMP" 2>/dev/null
                fi
            done

            (
                cd "$MERGE_TEMP" || exit 1
                zip -qr "../rebuilt_merged_base.apk" ./* 2>/dev/null
            )
            rm -rf "$MERGE_TEMP"
            
            if [ -f "rebuilt_merged_base.apk" ]; then
                TARGET_APK="rebuilt_merged_base.apk"
                echo -e "${GREEN}[✓] Berhasil menggabungkan split APK menjadi satu APK utuh!${RESET}"
            fi
        fi
    else
        TARGET_APK="$INPUT_PATH"
    fi

    # =============================================================
    # DETEKSI INFORMASI & TANDA TANGAN ASLI APK INPUT SECARA AKURAT
    # =============================================================
    APK_SIZE=$(du -h "$TARGET_APK" | cut -f1)
    PACKAGE_NAME=$(aapt dump badging "$TARGET_APK" 2>/dev/null | grep "package: name=" | awk -F"'" '{print $2}')
    APP_LABEL=$(aapt dump badging "$TARGET_APK" 2>/dev/null | grep "application-label:" | awk -F"'" '{print $2}')
    MIN_SDK=$(aapt dump badging "$TARGET_APK" 2>/dev/null | grep "sdkVersion:" | awk -F"'" '{print $2}')
    TARGET_SDK=$(aapt dump badging "$TARGET_APK" 2>/dev/null | grep "targetSdkVersion:" | awk -F"'" '{print $2}')

    SIG_INFO=$(apksigner verify --verbose --print-certs "$TARGET_APK" 2>&1)

    DETECTED_SCHEMES=()
    echo "$SIG_INFO" | grep -qi "Verified using v1 scheme (JAR signature): true" && DETECTED_SCHEMES+=("v1")
    echo "$SIG_INFO" | grep -qi "Verified using v2 scheme (APK Signature Scheme v2): true" && DETECTED_SCHEMES+=("v2")
    echo "$SIG_INFO" | grep -qi "Verified using v3 scheme (APK Signature Scheme v3): true" && DETECTED_SCHEMES+=("v3")
    echo "$SIG_INFO" | grep -qi "Verified using v4 scheme (APK Signature Scheme v4): true" && DETECTED_SCHEMES+=("v4")

    if [ ${#DETECTED_SCHEMES[@]} -gt 0 ]; then
        DETECTED_SIGNATURE=$(IFS="+"; echo "${DETECTED_SCHEMES[*]}")
    else
        DETECTED_SIGNATURE="Unsigned / Custom Signed"
    fi

    echo -e "\n${YELLOW}-------------------------------------------------------${RESET}"
    echo -e "${GREEN}INFO FILE TARGET (ASLI):${RESET}"
    echo -e "  - Path File      : ${INPUT_PATH}"
    echo -e "  - Ukuran File    : ${APK_SIZE}"
    echo -e "  - Nama Aplikasi  : ${APP_LABEL:-Tidak Terdeteksi}"
    echo -e "  - Package Name   : ${PACKAGE_NAME:-Tidak Terdeteksi}"
    echo -e "  - Min SDK        : ${MIN_SDK:-N/A}"
    echo -e "  - Target SDK     : ${TARGET_SDK:-N/A}"
    echo -e "  - Tanda Tangan   : ${CYAN}${DETECTED_SIGNATURE}${RESET}"
    echo -e "${YELLOW}-------------------------------------------------------${RESET}\n"

    # =============================================================
    # MENU METODE EKSEKUSI (DECOMPILATION VS DIRECT APK INJECTION)
    # =============================================================
    echo -e "${CYAN}PILIH METODE EKSEKUSI MODIFIKASI:${RESET}"
    echo -e "  ${GREEN}[1] Decompiled (Full Decouple dengan Apktool - Aman untuk Smali/Manifest/Name/Clone)${RESET}"
    echo -e "  ${GREEN}[2] Langsung dari APK (Injeksi file via APK tanpa decompile total - Lebih Cepat)${RESET}"
    read -p "Pilih metode [1-2] (Default 1): " EXEC_METHOD
    [ -z "$EXEC_METHOD" ] && EXEC_METHOD=1

    # =============================================================
    # MENU IDENTITAS APLIKASI (GANTI NAMA APLIKASI & CLONE PACKAGE)
    # =============================================================
    echo -e "\n${CYAN}=======================================================${RESET}"
    echo -e "${CYAN}          PENGATURAN IDENTITAS APLIKASI                ${RESET}"
    echo -e "${CYAN}=======================================================${RESET}"
    
    read -p "Ganti Nama Aplikasi (Kosongkan jika tetap): " NEW_APP_NAME
    read -p "Clone APK / Ganti Package Name (Kosongkan jika tetap): " NEW_PACKAGE_NAME

    TAG_IDENT=""
    if [ -n "$NEW_APP_NAME" ]; then
        TAG_IDENT="${TAG_IDENT}[RENAMED]"
    fi
    if [ -n "$NEW_PACKAGE_NAME" ]; then
        TAG_IDENT="${TAG_IDENT}[CLONE]"
    fi

    # =============================================================
    # MENU MODIFIKASI FITUR & OPSI STRATEGI DEX VIP
    # =============================================================
    echo -e "\n${CYAN}PILIH FITUR MODIFIKASI:${RESET}"
    echo -e "  ${GREEN}[1] Unlock VIP / Premium / Pro (Injeksi Hook VIP & Expiry Bypass)${RESET}"
    echo -e "  ${GREEN}[2] Remove Ads (Pembersihan Iklan Total & Layout Ads)${RESET}"
    echo -e "  ${GREEN}[3] Unlock VIP/Premium/Pro + Remove Ads (Paket Komplet)${RESET}"
    echo -e "  ${GREEN}[4] Lanjut tanpa modifikasi fitur (Hanya Rebuild & Sign)${RESET}"
    read -p "Pilihan kamu [1-4]: " MOD_CHOICE
    [ -z "$MOD_CHOICE" ] && MOD_CHOICE=4

    VIP_STRATEGY=1
    if [ "$MOD_CHOICE" -eq 1 ] || [ "$MOD_CHOICE" -eq 3 ]; then
        echo -e "\n${CYAN}PILIH STRATEGI INJEKSI DEX UNTUK UNLOCK VIP:${RESET}"
        echo -e "  ${GREEN}[1] Buat classes dex baru (smali_classesX tersendiri - Lebih bersih)${RESET}"
        echo -e "  ${GREEN}[2] Pakai classes dex yang ada (Injeksi langsung ke smali bawaan)${RESET}"
        read -p "Pilihan strategi DEX [1-2] (Default 1): " VIP_STRATEGY
        [ -z "$VIP_STRATEGY" ] && VIP_STRATEGY=1
    fi

    case $MOD_CHOICE in
        1) 
            SUB_DIR="MOD PREMIUM-DEX"
            TAG_MOD="[PREMIUM-DEX]" 
            ;;
        2) 
            SUB_DIR="REMOVE ADS"
            TAG_MOD="[NO-ADS]" 
            ;;
        3) 
            SUB_DIR="MOD PREMIUM-DEX + REMOVE ADS"
            TAG_MOD="[PREMIUM-DEX-NOADS]" 
            ;;
        *) 
            SUB_DIR="REBUILD ONLY"
            TAG_MOD="[REBUILD]" 
            ;;
    esac

    # =============================================================
    # MENU HAPUS ARSITEKTUR LIB (ABI) - DINAMIS & MULTI-SELECT
    # =============================================================
    echo -e "\n${CYAN}=======================================================${RESET}"
    echo -e "${CYAN}             PILIH ARSITEKTUR LIB (ABI)                ${RESET}"
    echo -e "${CYAN}=======================================================${RESET}"

    echo -e "${YELLOW}[*] Memeriksa daftar arsitektur 'lib/' dalam APK...${RESET}"
    ARCH_LIST=$(unzip -l "$TARGET_APK" "lib/*" 2>/dev/null | awk '{print $4}' | cut -d'/' -f2 | grep -v '^$' | sort -u)

    ARCHS_TO_REMOVE=()
    TAG_ARCH="ALL"

    if [ -z "$ARCH_LIST" ]; then
        echo -e "${YELLOW}[!] Tidak ditemukan folder 'lib/' pada APK ini. Melewati pembersihan ABI.${RESET}"
    else
        echo -e "\nFolder arsitektur yang ditemukan di APK:"
        i=1
        declare -A ARCH_MAP
        for ARCH in $ARCH_LIST; do
            echo -e "  ${GREEN}[$i]${RESET} $ARCH"
            ARCH_MAP[$i]=$ARCH
            ((i++))
        done

        echo -e "\n${CYAN}Silakan masukkan nomor arsitektur yang mau DIHAPUS.${RESET}"
        echo -e "Contoh: Ketik ${YELLOW}2 3 4${RESET} (dipisah spasi) atau tekan Enter untuk tidak menghapus apapun."
        read -p "Masukkan pilihan nomor: " ABI_CHOICES

        if [ -n "$ABI_CHOICES" ]; then
            for CHOICE in $ABI_CHOICES; do
                SELECTED_ARCH="${ARCH_MAP[$CHOICE]}"
                if [ -n "$SELECTED_ARCH" ]; then
                    ARCHS_TO_REMOVE+=("$SELECTED_ARCH")
                else
                    echo -e "${YELLOW}[!] Nomor pilihan [$CHOICE] tidak valid, dilewati.${RESET}"
                fi
            done
        fi

        if [ ${#ARCHS_TO_REMOVE[@]} -gt 0 ]; then
            TAG_ARCH="MODIFIED-LIB"
            echo -e "${GREEN}[✓] Arsitektur yang akan dihapus: ${ARCHS_TO_REMOVE[*]}${RESET}"
        else
            echo -e "${YELLOW}[*] Tidak ada arsitektur yang dihapus.${RESET}"
        fi
    fi

    # =============================================================
    # MENU KOMPRESI APK
    # =============================================================
    echo -e "\n${CYAN}=======================================================${RESET}"
    echo -e "${CYAN}                PILIH KOMPRESI APK                     ${RESET}"
    echo -e "${CYAN}=======================================================${RESET}"
    echo -e "Pilih tingkat kompresi file APK:"
    echo -e "  ${GREEN}[1] Ya (Ultra Compression Level 9 - Mengecilkan ukuran file APK)${RESET}"
    echo -e "  ${GREEN}[2] Tidak (Gunakan kompresi bawaan/standar)${RESET}"
    echo -e "  ${GREEN}[3] Tidak kompres (Store level 0 / Tanpa kompresi)${RESET}"
    read -p "Pilihan kamu [1-3] (Default 2): " COMPRESS_CHOICE
    [ -z "$COMPRESS_CHOICE" ] && COMPRESS_CHOICE=2

    # =============================================================
    # MENU SKEMA SIGNATURE DENGAN DESKRIPSI LENGKAP
    # =============================================================
    echo -e "\n${CYAN}=======================================================${RESET}"
    echo -e "${CYAN}             PILIH SKEMA TANDA TANGAN                  ${RESET}"
    echo -e "${CYAN}=======================================================${RESET}"
    echo -e "  ${YELLOW}[0] Force v1 + v2 (Rekomendasi Paling Aman & Kompatibel)${RESET}"
    echo -e "      -> Cocok untuk hampir semua versi Android (Lama & Baru)."
    echo -e "  ${GREEN}[1] v1 + v2 + v3${RESET}"
    echo -e "      -> Mendukung Android lama hingga Android Pie+ dengan key rotation."
    echo -e "  ${GREEN}[2] v1 + v2${RESET}"
    echo -e "      -> Format standar JAR signature ditambah APK Signature Scheme v2."
    echo -e "  ${GREEN}[3] v1 + v3${RESET}"
    echo -e "      -> Kombinasi tanda tangan JAR dan v3 tanpa v2."
    echo -e "  ${GREEN}[4] v1 Only${RESET}"
    echo -e "      -> Hanya JAR signature tradisional (Raw zip verification)."
    echo -e "  ${GREEN}[5] v2 + v3${RESET}"
    echo -e "      -> Skema modern tanpa v1 (Aman untuk Android 7.0 ke atas)."
    echo -e "  ${GREEN}[6] v2 Only${RESET}"
    echo -e "      -> Blok APK Signature v2 murni."
    echo -e "  ${GREEN}[7] v3 Only${RESET}"
    echo -e "      -> Blok APK Signature v3 murni (Key rotation support)."
    echo -e "  ${GREEN}[8] v1 + v2 + v3 + v3.1${RESET}"
    echo -e "      -> Format skema terlengkap termasuk dukungan Android 14+ (v3.1)."
    echo -e "  ${GREEN}[9] v1 + v2 + v3 + v4${RESET}"
    echo -e "      -> Skema komplit v1 hingga v4 (Mendukung Android 11+ Streaming/IncFS)."
    echo -e "${CYAN}=======================================================${RESET}"

    read -p "Pilih skema tanda tangan [0-9] (Default 0): " SIGN_CHOICE
    [ -z "$SIGN_CHOICE" ] && SIGN_CHOICE=0

    case $SIGN_CHOICE in
        0) SIG_FLAGS="--v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled false --v4-signing-enabled false" ;;
        1) SIG_FLAGS="--v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true --v4-signing-enabled false" ;;
        2) SIG_FLAGS="--v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled false --v4-signing-enabled false" ;;
        3) SIG_FLAGS="--v1-signing-enabled true --v2-signing-enabled false --v3-signing-enabled true --v4-signing-enabled false" ;;
        4) SIG_FLAGS="--v1-signing-enabled true --v2-signing-enabled false --v3-signing-enabled false --v4-signing-enabled false" ;;
        5) SIG_FLAGS="--v1-signing-enabled false --v2-signing-enabled true --v3-signing-enabled true --v4-signing-enabled false" ;;
        6) SIG_FLAGS="--v1-signing-enabled false --v2-signing-enabled true --v3-signing-enabled false --v4-signing-enabled false" ;;
        7) SIG_FLAGS="--v1-signing-enabled false --v2-signing-enabled false --v3-signing-enabled true --v4-signing-enabled false" ;;
        8) SIG_FLAGS="--v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true --v31-signing-enabled true --v4-signing-enabled false" ;;
        9) SIG_FLAGS="--v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true --v4-signing-enabled true" ;;
        *) SIG_FLAGS="--v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled false --v4-signing-enabled false" ;;
    esac

    # =============================================================
    # KEYSTORE CREDENTIALS & AUTOMATIC .JKS GENERATOR
    # =============================================================
    echo -e "\n${CYAN}=======================================================${RESET}"
    echo -e "${CYAN}             PENGATURAN CUSTOM KEYSTORE                ${RESET}"
    echo -e "${CYAN}=======================================================${RESET}"

    read -p "Masukkan Key Alias (Default: modder_alias): " KEY_ALIAS
    [ -z "$KEY_ALIAS" ] && KEY_ALIAS="modder_alias"

    read -p "Masukkan Password Keystore (Minimal 6 karakter, Default: password123): " KEY_PASS
    [ -z "$KEY_PASS" ] && KEY_PASS="password123"

    KEYSTORE_FILE="${KEY_ALIAS}_keystore.jks"

    if [ -f "$KEYSTORE_FILE" ]; then
        rm -f "$KEYSTORE_FILE"
        echo -e "${YELLOW}[*] Menghapus keystore lama untuk mencegah error mismatch password...${RESET}"
    fi

    echo -e "${CYAN}[*] Membuat file custom keystore (.jks) baru secara otomatis...${RESET}"
    KEYTOOL_LOG="keytool_err.log"
    rm -f "$KEYTOOL_LOG"

    keytool -genkey -v -keystore "$KEYSTORE_FILE" -alias "$KEY_ALIAS" \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -storepass "$KEY_PASS" -keypass "$KEY_PASS" \
        -dname "CN=Android Modder, OU=Mod, O=Dev, L=Jakarta, ST=ID, C=ID" > "$KEYTOOL_LOG" 2>&1

    if [ -f "$KEYSTORE_FILE" ]; then
        echo -e "${GREEN}[✓] Keystore berhasil dibuat: ${KEYSTORE_FILE}${RESET}"
        rm -f "$KEYTOOL_LOG"
    else
        echo -e "${RED}[!] Gagal membuat file keystore .jks! Detail Error:${RESET}"
        cat "$KEYTOOL_LOG"
        rm -f "$KEYTOOL_LOG"
        read -p "Tekan Enter untuk mencoba lagi..."
        continue
    fi

    echo -e "${GREEN}[✓] Alias: $KEY_ALIAS | Password: $KEY_PASS${RESET}"

    # =============================================================
    # DEFINISI PATH OUTPUT FILE AKHIR
    # =============================================================
    OUTPUT_DIR="/storage/emulated/0/[APK MOD]/${SUB_DIR}"
    mkdir -p "$OUTPUT_DIR"

    FINAL_FILE_NAME="${RAW_NAME} ${TAG_ARCH} ${TAG_IDENT} ${TAG_MOD}.apk"
    FINAL_APK="${OUTPUT_DIR}/${FINAL_FILE_NAME}"

    UNALIGNED_APK="unsigned_unaligned.apk"
    ALIGNED_APK="unsigned_aligned.apk"
    rm -f "$UNALIGNED_APK" "$ALIGNED_APK"

    # =============================================================
    # EKSEKUSI BERDASARKAN METODE (1: DECOMPILED / 2: DIRECT APK)
    # =============================================================
    if [ "$EXEC_METHOD" -eq 1 ]; then
        # ---------------------------------------------------------
        # METODE 1: DECOMPILATION (APKTOOL)
        # ---------------------------------------------------------
        WORK_DIR="decompiled_apk_temp"
        LOG_FILE="decompile_err.log"
        rm -rf "$WORK_DIR" "$LOG_FILE"

        (apktool d "$TARGET_APK" -o "$WORK_DIR" -f > "$LOG_FILE" 2>&1) &
        PID=$!
        show_dir_progress "Memproses Decompile APK & Ekstraksi Folder" "$WORK_DIR" "$PID"
        wait $PID

        if [ ! -d "$WORK_DIR" ]; then
            echo -e "${RED}[!] Gagal melakukan decompile APK.${RESET}"
            cat "$LOG_FILE"
            rm -f "$LOG_FILE"
            rm -rf "$TEMP_SPLIT_DIR" "rebuilt_merged_base.apk"
            read -p "Tekan Enter untuk mencoba lagi..."
            continue
        fi
        rm -f "$LOG_FILE"

        # ---------------------------------------------------------
        # PROSES GANTI NAMA APLIKASI & CLONE PACKAGE NAME
        # ---------------------------------------------------------
        (
            # 1. Ganti Nama Aplikasi (App Name)
            if [ -n "$NEW_APP_NAME" ]; then
                # Ganti langsung android:label pada tag <application> jika berupa string hardcoded
                sed -i 's/android:label="[^"]*"/android:label="'"$NEW_APP_NAME"'"/g' "$WORK_DIR/AndroidManifest.xml" 2>/dev/null
                
                # Update atau tambahkan 'app_name' di res/values/strings.xml
                if [ -f "$WORK_DIR/res/values/strings.xml" ]; then
                    if grep -q 'name="app_name"' "$WORK_DIR/res/values/strings.xml"; then
                        sed -i 's/<string name="app_name">.*<\/string>/<string name="app_name">'"$NEW_APP_NAME"'<\/string>/g' "$WORK_DIR/res/values/strings.xml"
                    else
                        sed -i 's/<\/resources>/  <string name="app_name">'"$NEW_APP_NAME"'<\/string>\n<\/resources>/' "$WORK_DIR/res/values/strings.xml"
                    fi
                fi
            fi

            # 2. Clone APK (Ganti Package Name)
            if [ -n "$NEW_PACKAGE_NAME" ] && [ -n "$PACKAGE_NAME" ]; then
                # Replace package name di AndroidManifest.xml
                sed -i "s/package=\"$PACKAGE_NAME\"/package=\"$NEW_PACKAGE_NAME\"/g" "$WORK_DIR/AndroidManifest.xml" 2>/dev/null
                
                # Replace package name di apktool.yml
                if [ -f "$WORK_DIR/apktool.yml" ]; then
                    sed -i "s/cur_package: $PACKAGE_NAME/cur_package: $NEW_PACKAGE_NAME/g" "$WORK_DIR/apktool.yml" 2>/dev/null
                    sed -i "s/renameManifestPackage: .*/renameManifestPackage: $NEW_PACKAGE_NAME/g" "$WORK_DIR/apktool.yml" 2>/dev/null
                fi
            fi
        ) &
        PID=$!
        show_progress "Memproses Perubahan Nama Aplikasi & Clone Package Name" "$PID"
        wait $PID

        # Injeksi Hook / Remove Ads (Termasuk String Methods)
        (
            if [ "$MOD_CHOICE" -eq 1 ] || [ "$MOD_CHOICE" -eq 3 ]; then
                if [ "$VIP_STRATEGY" -eq 1 ]; then
                    HIGHEST_DEX=1
                    for d in "$WORK_DIR"/smali*; do
                        if [ -d "$d" ]; then
                            num=$(echo "$d" | sed -n 's/.*smali_classes\([0-9]*\)/\1/p')
                            [ -z "$num" ] && num=1
                            [ "$num" -gt "$HIGHEST_DEX" ] && HIGHEST_DEX=$num
                        fi
                    done
                    NEXT_DEX=$((HIGHEST_DEX + 1))
                    TARGET_SMALI_DIR="$WORK_DIR/smali_classes$NEXT_DEX"
                else
                    TARGET_SMALI_DIR="$WORK_DIR/smali"
                fi

                mkdir -p "$TARGET_SMALI_DIR/com/modder/bypass"

                cat << 'EOF' > "$TARGET_SMALI_DIR/com/modder/bypass/VipBypass.smali"
.class public Lcom/modder/bypass/VipBypass;
.super Ljava/lang/Object;
.source "VipBypass.smali"

.method public constructor <init>()V
    .locals 0
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    return-void
.end method

# --- BOOLEAN METHODS ---
.method public static isVip()Z
    .locals 1
    const/4 v0, 0x1
    return v0
.end method

.method public static isPremium()Z
    .locals 1
    const/4 v0, 0x1
    return v0
.end method

.method public static isPro()Z
    .locals 1
    const/4 v0, 0x1
    return v0
.end method

.method public static isSubscribed()Z
    .locals 1
    const/4 v0, 0x1
    return v0
.end method

.method public static isLifetime()Z
    .locals 1
    const/4 v0, 0x1
    return v0
.end method

# --- NUMERIC & DATE METHODS ---
.method public static getExpiryDate()J
    .locals 2
    # Returns 253402300799000L (31 Des 9999 23:59:59 GMT)
    const-wide v0, 0x0000e677d21fdbffL
    return-wide v0
.end method

.method public static getRemainingDays()I
    .locals 1
    const v0, 0x7fffffff
    return v0
.end method

# --- STRING METHODS (VIP, PRO, PREMIUM, LIFETIME) ---
.method public static getVipStatus()Ljava/lang/String;
    .locals 1
    const-string v0, "VIP"
    return-object v0
.end method

.method public static getAccountType()Ljava/lang/String;
    .locals 1
    const-string v0, "Premium"
    return-object v0
.end method

.method public static getSubscriptionLevel()Ljava/lang/String;
    .locals 1
    const-string v0, "Pro"
    return-object v0
.end method

.method public static getLicenseType()Ljava/lang/String;
    .locals 1
    const-string v0, "Lifetime"
    return-object v0
.end method
EOF
            fi

            if [ "$MOD_CHOICE" -eq 2 ] || [ "$MOD_CHOICE" -eq 3 ]; then
                sed -i '/com.google.android.gms.ads/d' "$WORK_DIR/AndroidManifest.xml" 2>/dev/null
                sed -i '/com.applovin/d' "$WORK_DIR/AndroidManifest.xml" 2>/dev/null
                sed -i '/com.unity3d.services.ads/d' "$WORK_DIR/AndroidManifest.xml" 2>/dev/null
                sed -i '/com.facebook.ads/d' "$WORK_DIR/AndroidManifest.xml" 2>/dev/null
                sed -i '/com.startapp/d' "$WORK_DIR/AndroidManifest.xml" 2>/dev/null

                ADS_DEX_DIR="$WORK_DIR/smali_classes2"
                [ ! -d "$ADS_DEX_DIR" ] && ADS_DEX_DIR="$WORK_DIR/smali"
                mkdir -p "$ADS_DEX_DIR/com/modder/ads"

                cat << 'EOF' > "$ADS_DEX_DIR/com/modder/ads/AdBlocker.smali"
.class public Lcom/modder/ads/AdBlocker;
.super Ljava/lang/Object;
.source "AdBlocker.smali"

.method public constructor <init>()V
    .locals 0
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    return-void
.end method

.method public static disableAd()V
    .locals 0
    return-void
.end method

.method public static isAdEnabled()Z
    .locals 1
    const/4 v0, 0x0
    return v0
.end method
EOF
            fi
        ) &
        PID=$!
        if [ "$MOD_CHOICE" -eq 1 ]; then
            show_progress "Menyuntikkan Modul Hook Premium / VIP / Pro / Lifetime (Boolean & String)" "$PID"
        elif [ "$MOD_CHOICE" -eq 2 ]; then
            show_progress "Menjalankan Pembersihan Iklan & Manifest Ads" "$PID"
        elif [ "$MOD_CHOICE" -eq 3 ]; then
            show_progress "Menyuntikkan Hook VIP/Pro/Lifetime & Pembersihan Iklan" "$PID"
        else
            show_progress "Menyiapkan File Tanpa Modifikasi Fitur" "$PID"
        fi
        wait $PID

        # Pembersihan Arsitektur Lib & Resource
        LIB_DIR="$WORK_DIR/lib"
        (
            if [ -d "$LIB_DIR" ] && [ ${#ARCHS_TO_REMOVE[@]} -gt 0 ]; then
                for DEL_ARCH in "${ARCHS_TO_REMOVE[@]}"; do
                    rm -rf "$LIB_DIR/$DEL_ARCH"
                done
            fi

            find "$WORK_DIR/res" -type f -name '*$*' 2>/dev/null | while read -r file; do
                dir=$(dirname "$file")
                filename=$(basename "$file")
                new_filename=$(echo "$filename" | sed 's/\$/_/g')
                mv "$file" "$dir/$new_filename"
            done
            find "$WORK_DIR/res" -type f -name "*.xml" -exec sed -i 's/\$/_/g' {} + 2>/dev/null
        ) &
        PID=$!
        show_progress "Pembersihan Struktur Lib & Resource" "$PID"
        wait $PID

        # Rebuild APK
        BUILD_LOG="rebuild_err.log"
        rm -f "$UNALIGNED_APK" "$BUILD_LOG"

        (apktool b "$WORK_DIR" -o "$UNALIGNED_APK" > "$BUILD_LOG" 2>&1) &
        PID=$!
        show_compress_progress "Membangun Ulang APK (Rebuilding)" "$UNALIGNED_APK" "$PID"
        wait $PID

        if [ ! -f "$UNALIGNED_APK" ]; then
            echo -e "${RED}[!] Gagal rebuild APK. Cek log error di bawah:${RESET}"
            cat "$BUILD_LOG"
            rm -f "$BUILD_LOG"
            rm -rf "$TEMP_SPLIT_DIR" "rebuilt_merged_base.apk"
            read -p "Tekan Enter untuk mencoba lagi..."
            continue
        fi
        rm -f "$BUILD_LOG"

    else
        # ---------------------------------------------------------
        # METODE 2: LANGSUNG DARI APK (DIRECT APK INJECTION IN-PLACE)
        # ---------------------------------------------------------
        echo -e "${CYAN}[*] Memproses modifikasi langsung pada file APK...${RESET}"
        if [ -n "$NEW_APP_NAME" ] || [ -n "$NEW_PACKAGE_NAME" ]; then
            echo -e "${YELLOW}[!] Catatan: Mengganti Nama Aplikasi atau Package Name (Clone) memerlukan Decompile (Metode 1) untuk hasil yang stabil.${RESET}"
        fi

        # 1. BUAT BACKUP APK ASLI (KOMPRESI ULTRA LEVEL 9)
        BACKUP_DIR="${OUTPUT_DIR}/BACKUP_ORIGINAL"
        mkdir -p "$BACKUP_DIR"
        BACKUP_ZIP="${BACKUP_DIR}/${RAW_NAME}_ORIGINAL_BACKUP.zip"

        (
            zip -9 -q "$BACKUP_ZIP" "$TARGET_APK" 2>/dev/null
        ) &
        PID=$!
        show_compress_progress "Membuat Backup Ultra Compression (Level 9)" "$BACKUP_ZIP" "$PID"
        wait $PID

        # 2. SALIN APK INPUT MENJADI UNALIGNED TARGET
        rm -f "$UNALIGNED_APK"
        cp "$TARGET_APK" "$UNALIGNED_APK"

        # 3. HAPUS FILE / FOLDER SECARA LANGSUNG (IN-PLACE) TANPA EKSTRAKSI
        (
            if [ ${#ARCHS_TO_REMOVE[@]} -gt 0 ]; then
                for DEL_ARCH in "${ARCHS_TO_REMOVE[@]}"; do
                    zip -d "$UNALIGNED_APK" "lib/$DEL_ARCH/*" 2>/dev/null
                done
            fi

            if [ "$MOD_CHOICE" -eq 2 ] || [ "$MOD_CHOICE" -eq 3 ]; then
                zip -d "$UNALIGNED_APK" "res/layout/*ad*.xml" 2>/dev/null
                zip -d "$UNALIGNED_APK" "res/layout/*banner*.xml" 2>/dev/null
            fi
        ) &
        PID=$!
        show_progress "Memproses Manipulasi In-Place pada APK" "$PID"
        wait $PID
    fi

    # =============================================================
    # ZIPALIGN & KOMPRESI (OPSIONAL BERDASARKAN PILIHAN)
    # =============================================================
    rm -f "$ALIGNED_APK"
    ZAL_LOG="zipalign_err.log"

    if [ "$COMPRESS_CHOICE" -eq 1 ]; then
        (zipalign -p -f -v 4 "$UNALIGNED_APK" "$ALIGNED_APK" > "$ZAL_LOG" 2>&1) &
        PID=$!
        show_compress_progress "Memproses Alignment & Optimasi 4-Byte" "$ALIGNED_APK" "$PID"
        wait $PID

        ULTRA_COMPRESSED_APK="ultra_compressed.apk"
        rm -f "$ULTRA_COMPRESSED_APK"

        (
            TEMP_ULTRA_DIR="ultra_zip_temp"
            rm -rf "$TEMP_ULTRA_DIR"
            mkdir -p "$TEMP_ULTRA_DIR"
            
            unzip -q "$ALIGNED_APK" -d "$TEMP_ULTRA_DIR" 2>/dev/null
            
            cd "$TEMP_ULTRA_DIR" || exit 1
            zip -9 -qr "../$ULTRA_COMPRESSED_APK" ./* -x "resources.arsc" 2>/dev/null
            if [ -f "resources.arsc" ]; then
                zip -0 -qr "../$ULTRA_COMPRESSED_APK" "resources.arsc" 2>/dev/null
            fi
            cd ..
            
            rm -rf "$TEMP_ULTRA_DIR"
        ) &
        PID=$!
        show_compress_progress "Ultra Compression Level 9 (Aman Untuk OS Android)" "$ULTRA_COMPRESSED_APK" "$PID"
        wait $PID

        if [ -f "$ULTRA_COMPRESSED_APK" ]; then
            zipalign -p -f -v 4 "$ULTRA_COMPRESSED_APK" "$ALIGNED_APK" > /dev/null 2>&1
            rm -f "$ULTRA_COMPRESSED_APK"
        fi

    elif [ "$COMPRESS_CHOICE" -eq 3 ]; then
        UNCOMPRESSED_TEMP_APK="uncompressed_temp.apk"
        rm -f "$UNCOMPRESSED_TEMP_APK"

        (
            TEMP_STORE_DIR="store_zip_temp"
            rm -rf "$TEMP_STORE_DIR"
            mkdir -p "$TEMP_STORE_DIR"

            unzip -q "$UNALIGNED_APK" -d "$TEMP_STORE_DIR" 2>/dev/null

            cd "$TEMP_STORE_DIR" || exit 1
            zip -0 -qr "../$UNCOMPRESSED_TEMP_APK" ./* 2>/dev/null
            cd ..

            rm -rf "$TEMP_STORE_DIR"
        ) &
        PID=$!
        show_compress_progress "Memproses APK Tanpa Kompresi (Store Level 0)" "$UNCOMPRESSED_TEMP_APK" "$PID"
        wait $PID

        (zipalign -p -f -v 4 "$UNCOMPRESSED_TEMP_APK" "$ALIGNED_APK" > "$ZAL_LOG" 2>&1) &
        PID=$!
        show_compress_progress "Memproses Alignment & Optimasi 4-Byte" "$ALIGNED_APK" "$PID"
        wait $PID
        rm -f "$UNCOMPRESSED_TEMP_APK"

    else
        (zipalign -p -f -v 4 "$UNALIGNED_APK" "$ALIGNED_APK" > "$ZAL_LOG" 2>&1) &
        PID=$!
        show_compress_progress "Memproses Alignment & Optimasi 4-Byte (Kompresi Standar)" "$ALIGNED_APK" "$PID"
        wait $PID
    fi

    if [ ! -f "$ALIGNED_APK" ]; then
        echo -e "${RED}[!] Gagal pada tahap Zipalign. Log error:${RESET}"
        cat "$ZAL_LOG"
        rm -f "$ZAL_LOG"
        rm -rf "$TEMP_SPLIT_DIR" "rebuilt_merged_base.apk"
        read -p "Tekan Enter untuk mencoba lagi..."
        continue
    fi
    rm -f "$ZAL_LOG"

    # =============================================================
    # SIGNING AKHIR
    # =============================================================
    rm -f "$FINAL_APK"
    SIGN_LOG="sign_err.log"
    (apksigner sign --ks "$KEYSTORE_FILE" \
        --ks-pass pass:"$KEY_PASS" \
        --ks-key-alias "$KEY_ALIAS" \
        --key-pass pass:"$KEY_PASS" \
        $SIG_FLAGS \
        --out "$FINAL_APK" "$ALIGNED_APK" > "$SIGN_LOG" 2>&1) &
    PID=$!
    show_compress_progress "Memproses Tanda Tangan (Signing)" "$FINAL_APK" "$PID"
    wait $PID

    if [ ! -f "$FINAL_APK" ]; then
        echo -e "${RED}[!] Gagal pada tahap Signing APK. Log error:${RESET}"
        cat "$SIGN_LOG"
        rm -f "$SIGN_LOG"
        rm -rf "$TEMP_SPLIT_DIR" "rebuilt_merged_base.apk"
        read -p "Tekan Enter untuk mencoba lagi..."
        continue
    fi
    rm -f "$SIGN_LOG"

    # Bersihkan file sementara
    rm -rf "$WORK_DIR" "$UNALIGNED_APK" "$ALIGNED_APK" "$TEMP_SPLIT_DIR" "rebuilt_merged_base.apk"

    # =============================================================
    # HASIL AKHIR
    # =============================================================
    if [ -f "$FINAL_APK" ]; then
        FINAL_SIZE=$(du -h "$FINAL_APK" | cut -f1)
        echo -e "\n${GREEN}=======================================================${RESET}"
        echo -e "${GREEN}             PROSES MODIFIKASI SELESAI!                ${RESET}"
        echo -e "${GREEN}=======================================================${RESET}"
        echo -e "  - Path Folder  : ${YELLOW}${OUTPUT_DIR}${RESET}"
        echo -e "  - File Output  : ${YELLOW}${FINAL_FILE_NAME}${RESET}"
        echo -e "  - Nama Aplikasi: ${CYAN}${NEW_APP_NAME:-$APP_LABEL}${RESET}"
        echo -e "  - Package Name : ${CYAN}${NEW_PACKAGE_NAME:-$PACKAGE_NAME}${RESET}"
        echo -e "  - Ukuran Akhir : ${YELLOW}${FINAL_SIZE}${RESET}"
        echo -e "  - Keystore JKS : ${YELLOW}${KEYSTORE_FILE}${RESET}"
        echo -e "  - Mode Kompresi: ${CYAN}$([ $COMPRESS_CHOICE -eq 1 ] && echo "Ultra Compression (Level 9)" || { [ $COMPRESS_CHOICE -eq 3 ] && echo "Tanpa Kompresi (Level 0)"; } || echo "Kompresi Standar")${RESET}"
        echo -e "  - Metode Eksekusi: ${CYAN}$([ $EXEC_METHOD -eq 1 ] && echo "Decompiled (Apktool)" || echo "Direct APK Injection")${RESET}"
        echo -e "${GREEN}=======================================================${RESET}\n"
    else
        echo -e "${RED}[!] Gagal menyelesaikan proses modifikasi APK.${RESET}"
    fi

    # =============================================================
    # OPSI PERULANGAN / LANJUT KE APK LAIN
    # =============================================================
    echo -e "${CYAN}=======================================================${RESET}"
    echo -e "${CYAN}             APAKAH INGIN MELANJUTKAN?                 ${RESET}"
    echo -e "${CYAN}=======================================================${RESET}"
    echo -e "  ${GREEN}[1] Ya (Lanjut ke APK lain)${RESET}"
    echo -e "  ${RED}[2] Keluar skrip${RESET}"
    read -p "Pilihan kamu [1-2]: " NEXT_CHOICE

    if [ "$NEXT_CHOICE" -eq 1 ]; then
        echo -e "${YELLOW}[*] Memulai ulang skrip...${RESET}"
        sleep 1
    else
        echo -e "${GREEN}[✓] Terima kasih! Skrip selesai.${RESET}"
        exit 0
    fi
done
