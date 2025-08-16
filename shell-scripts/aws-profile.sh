aws-switch() {
  local profile region
  profile=$(grep -E '^\[profile .+\]' ~/.aws/config | sed 's/^\[profile \(.*\)\]$/\1/' | fzf)
  [ -z "$profile" ] && { echo "No profile selected"; return 1; }

  # Get region from the selected profile
  region=$(awk -v p="$profile" '
    $0 ~ "\\[profile "p"\\]" {f=1; next}
    f && $1=="region" {print $3; exit}
    f && /^\[profile / {f=0}
  ' ~/.aws/config)

  export AWS_PROFILE="$profile"
  [ -n "$region" ] && export AWS_REGION="$region"

  # Check if creds work; if not, run sso login
  if ! aws sts get-caller-identity --profile "$profile" >/dev/null 2>&1; then
    echo "🔑 Logging in with SSO for $profile..."
    if ! aws sso login --profile "$profile"; then
      echo "❌ SSO login failed for $profile"
      return 1
    fi
  fi

  echo "✅ AWS_PROFILE=$AWS_PROFILE"
  [ -n "$AWS_REGION" ] && echo "🌍 AWS_REGION=$AWS_REGION"
  aws sts get-caller-identity --output text 2>/dev/null | awk '{print "👤 " $1 " " $2 " " $3}'
}

# Pick a continent, then a region under it. Usage:
#   aws-region              # set AWS_REGION for this shell only
#   aws-region --persist    # also write region to ~/.aws/config for current AWS_PROFILE
aws-region() {
  command -v fzf >/dev/null 2>&1 || { echo "fzf not found"; return 1; }

  local persist=0
  [ "$1" = "--persist" ] && persist=1

  # 1) Pick continent
  local continent
  continent=$(printf "%s\n" \
    "North America" \
    "South America" \
    "Europe" \
    "Asia Pacific" \
    "Africa" \
    "Middle East" \
    | fzf --prompt="Continent > ")
  [ -z "$continent" ] && { echo "No continent selected"; return 1; }

  # 2) Regions per continent (code + friendly name)
  local regions
  case "$continent" in
    "North America") regions=$(cat <<'EOF'
us-east-1    N. Virginia
us-east-2    Ohio
us-west-1    N. California
us-west-2    Oregon
ca-central-1 Canada (Central)
EOF
);;
    "South America") regions=$(cat <<'EOF'
sa-east-1    São Paulo
EOF
);;
    "Europe") regions=$(cat <<'EOF'
eu-north-1   Stockholm
eu-west-1    Ireland
eu-west-2    London
eu-west-3    Paris
eu-central-1 Frankfurt
eu-central-2 Zurich
eu-south-1   Milan
eu-south-2   Spain
EOF
);;
    "Asia Pacific") regions=$(cat <<'EOF'
ap-east-1    Hong Kong
ap-south-1   Mumbai
ap-south-2   Hyderabad
ap-southeast-1 Singapore
ap-southeast-2 Sydney
ap-southeast-3 Jakarta
ap-southeast-4 Melbourne
ap-northeast-1 Tokyo
ap-northeast-2 Seoul
ap-northeast-3 Osaka
EOF
);;
    "Africa") regions=$(cat <<'EOF'
af-south-1   Cape Town
EOF
);;
    "Middle East") regions=$(cat <<'EOF'
me-south-1   Bahrain
me-central-1 UAE
il-central-1 Tel Aviv
EOF
);;
  esac

  # 3) Pick region within the chosen continent
  local selection region
  selection=$(printf "%s\n" "$regions" | fzf --prompt="$continent > " --with-nth=1,2 --tac)
  [ -z "$selection" ] && { echo "No region selected"; return 1; }
  region=$(printf "%s" "$selection" | awk '{print $1}')

  export AWS_REGION="$region"
  echo "🌍 AWS_REGION set to: $AWS_REGION" \
       $( [ -n "$AWS_PROFILE" ] && printf "(profile: %s)" "$AWS_PROFILE" )

  # Optional: persist to config for current profile
  if [ $persist -eq 1 ]; then
    local prof="${AWS_PROFILE:-default}"
    aws configure set region "$AWS_REGION" --profile "$prof" && \
      echo "📝 Persisted region to profile [$prof] in ~/.aws/config"
  fi
}
