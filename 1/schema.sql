-- ============================================================================
-- CELLULES CITOYENNES — Schema PostgreSQL + PostGIS
-- Plateforme de maillage territorial pour l'intelligence collective
-- ============================================================================

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- ============================================================================
-- ENUMS
-- ============================================================================

CREATE TYPE theme_type AS ENUM (
    'mobilite', 'environnement', 'social', 'numerique', 
    'culture', 'economie', 'democratie', 'education', 'sante', 'autre'
);

CREATE TYPE cellule_status AS ENUM (
    'draft', 'recruiting', 'active', 'completed', 'archived'
);

CREATE TYPE participant_role AS ENUM (
    'creator', 'member', 'observer'
);

CREATE TYPE participant_status AS ENUM (
    'active', 'left', 'removed'
);

CREATE TYPE atelier_type AS ENUM (
    'async', 'live', 'hybrid'
);

CREATE TYPE atelier_status AS ENUM (
    'planned', 'async_phase', 'live_phase', 'completed', 'cancelled'
);

CREATE TYPE contribution_type AS ENUM (
    'idea', 'comment', 'vote', 'resource', 'synthesis', 'decision'
);

CREATE TYPE match_status AS ENUM (
    'suggested', 'accepted', 'rejected', 'meeting_planned', 'completed'
);

CREATE TYPE org_type AS ENUM (
    'asbl', 'collectif', 'commune', 'institution', 'autre'
);

CREATE TYPE zone_type AS ENUM (
    'bxl', 'wal'
);

-- ============================================================================
-- TABLES
-- ============================================================================

-- Organizations (associations, collectifs, communes)
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    type org_type DEFAULT 'autre',
    description TEXT,
    website TEXT,
    logo_url TEXT,
    verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Users (extends Supabase auth.users)
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    pseudo TEXT NOT NULL,
    email TEXT,
    avatar_url TEXT,
    bio TEXT,
    organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL,
    location GEOGRAPHY(POINT, 4326),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Grid nodes (pre-generated coverage of FWB)
CREATE TABLE grid_nodes (
    id TEXT PRIMARY KEY, -- e.g., "WAL-50.450/4.850"
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    zone zone_type NOT NULL,
    commune TEXT,
    province TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Spatial index for grid nodes
CREATE INDEX idx_grid_nodes_location ON grid_nodes USING GIST(location);

-- Cellules (citizen cells)
CREATE TABLE cellules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    creator_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    node_id TEXT REFERENCES grid_nodes(id),
    
    title TEXT NOT NULL,
    description TEXT,
    theme theme_type DEFAULT 'autre',
    tags TEXT[] DEFAULT '{}',
    
    -- Location
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    territory GEOGRAPHY(POLYGON, 4326), -- influence perimeter
    radius_km FLOAT DEFAULT 5.0,
    
    -- Settings
    status cellule_status DEFAULT 'draft',
    min_participants INT DEFAULT 5 CHECK (min_participants >= 2),
    max_participants INT DEFAULT 9 CHECK (max_participants <= 50),
    
    -- Links
    trace_url TEXT, -- publication link
    external_links JSONB DEFAULT '[]',
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    activated_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);

-- Spatial indexes for cellules
CREATE INDEX idx_cellules_location ON cellules USING GIST(location);
CREATE INDEX idx_cellules_territory ON cellules USING GIST(territory);
CREATE INDEX idx_cellules_status ON cellules(status);
CREATE INDEX idx_cellules_theme ON cellules(theme);
CREATE INDEX idx_cellules_creator ON cellules(creator_id);

-- Participants
CREATE TABLE participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cellule_id UUID NOT NULL REFERENCES cellules(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    role participant_role DEFAULT 'member',
    status participant_status DEFAULT 'active',
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    left_at TIMESTAMPTZ,
    
    UNIQUE(cellule_id, user_id)
);

CREATE INDEX idx_participants_cellule ON participants(cellule_id);
CREATE INDEX idx_participants_user ON participants(user_id);

-- Ateliers (workshops)
CREATE TABLE ateliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cellule_id UUID NOT NULL REFERENCES cellules(id) ON DELETE CASCADE,
    
    title TEXT NOT NULL,
    description TEXT,
    type atelier_type DEFAULT 'hybrid',
    status atelier_status DEFAULT 'planned',
    
    -- Async phase (14 days)
    async_start TIMESTAMPTZ,
    async_end TIMESTAMPTZ,
    
    -- Live phase (48h)
    live_start TIMESTAMPTZ,
    live_end TIMESTAMPTZ,
    
    -- External platforms used
    platform_urls JSONB DEFAULT '{}', -- {"visio": "https://...", "chat": "https://...", ...}
    
    -- Outcomes
    outcomes JSONB DEFAULT '{}', -- {"decisions": [], "actions": [], "synthesis": ""}
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ateliers_cellule ON ateliers(cellule_id);
CREATE INDEX idx_ateliers_status ON ateliers(status);

-- Contributions (ideas, votes, resources during ateliers)
CREATE TABLE contributions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    atelier_id UUID NOT NULL REFERENCES ateliers(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    
    type contribution_type DEFAULT 'idea',
    content TEXT NOT NULL,
    metadata JSONB DEFAULT '{}', -- votes count, links, etc.
    
    parent_id UUID REFERENCES contributions(id) ON DELETE CASCADE, -- for threads
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_contributions_atelier ON contributions(atelier_id);
CREATE INDEX idx_contributions_user ON contributions(user_id);
CREATE INDEX idx_contributions_type ON contributions(type);

-- Matches (territorial matching between cellules)
CREATE TABLE matches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cellule_a_id UUID NOT NULL REFERENCES cellules(id) ON DELETE CASCADE,
    cellule_b_id UUID NOT NULL REFERENCES cellules(id) ON DELETE CASCADE,
    
    score FLOAT DEFAULT 0, -- calculated matching score
    distance_km FLOAT,
    common_themes TEXT[],
    
    status match_status DEFAULT 'suggested',
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(cellule_a_id, cellule_b_id),
    CHECK (cellule_a_id < cellule_b_id) -- avoid duplicates
);

CREATE INDEX idx_matches_cellule_a ON matches(cellule_a_id);
CREATE INDEX idx_matches_cellule_b ON matches(cellule_b_id);
CREATE INDEX idx_matches_status ON matches(status);

-- Invitations
CREATE TABLE invitations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cellule_id UUID NOT NULL REFERENCES cellules(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES profiles(id),
    
    code TEXT UNIQUE NOT NULL, -- short code for sharing
    email TEXT, -- optional: direct invite to email
    
    max_uses INT DEFAULT 1,
    uses INT DEFAULT 0,
    expires_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_invitations_code ON invitations(code);
CREATE INDEX idx_invitations_cellule ON invitations(cellule_id);

-- Activity log
CREATE TABLE activity_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    cellule_id UUID REFERENCES cellules(id) ON DELETE CASCADE,
    atelier_id UUID REFERENCES ateliers(id) ON DELETE CASCADE,
    
    action TEXT NOT NULL, -- 'cellule_created', 'participant_joined', 'atelier_started', etc.
    metadata JSONB DEFAULT '{}',
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_activity_cellule ON activity_log(cellule_id);
CREATE INDEX idx_activity_user ON activity_log(user_id);
CREATE INDEX idx_activity_created ON activity_log(created_at DESC);

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function to count active participants
CREATE OR REPLACE FUNCTION get_participant_count(cellule_uuid UUID)
RETURNS INT AS $$
    SELECT COUNT(*)::INT 
    FROM participants 
    WHERE cellule_id = cellule_uuid AND status = 'active';
$$ LANGUAGE SQL STABLE;

-- Function to calculate distance between two cellules
CREATE OR REPLACE FUNCTION cellule_distance(a_id UUID, b_id UUID)
RETURNS FLOAT AS $$
    SELECT ST_Distance(a.location, b.location) / 1000 -- km
    FROM cellules a, cellules b
    WHERE a.id = a_id AND b.id = b_id;
$$ LANGUAGE SQL STABLE;

-- Function to find nearby cellules
CREATE OR REPLACE FUNCTION find_nearby_cellules(
    center_location GEOGRAPHY,
    radius_meters FLOAT DEFAULT 10000,
    exclude_id UUID DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    title TEXT,
    theme theme_type,
    distance_km FLOAT,
    participant_count INT
) AS $$
    SELECT 
        c.id,
        c.title,
        c.theme,
        ST_Distance(c.location, center_location) / 1000 AS distance_km,
        get_participant_count(c.id) AS participant_count
    FROM cellules c
    WHERE ST_DWithin(c.location, center_location, radius_meters)
      AND c.status IN ('recruiting', 'active')
      AND (exclude_id IS NULL OR c.id != exclude_id)
    ORDER BY distance_km;
$$ LANGUAGE SQL STABLE;

-- Function to calculate match score
CREATE OR REPLACE FUNCTION calculate_match_score(a_id UUID, b_id UUID)
RETURNS FLOAT AS $$
DECLARE
    dist FLOAT;
    theme_match BOOLEAN;
    size_diff INT;
    score FLOAT := 0;
BEGIN
    -- Get distance
    SELECT cellule_distance(a_id, b_id) INTO dist;
    
    -- Distance score (max 50 points, decreases with distance)
    IF dist <= 5 THEN
        score := score + 50;
    ELSIF dist <= 10 THEN
        score := score + 40;
    ELSIF dist <= 20 THEN
        score := score + 25;
    ELSIF dist <= 50 THEN
        score := score + 10;
    END IF;
    
    -- Theme match (30 points)
    SELECT (a.theme = b.theme) INTO theme_match
    FROM cellules a, cellules b
    WHERE a.id = a_id AND b.id = b_id;
    
    IF theme_match THEN
        score := score + 30;
    END IF;
    
    -- Size similarity (20 points max)
    SELECT ABS(get_participant_count(a_id) - get_participant_count(b_id)) INTO size_diff;
    score := score + GREATEST(0, 20 - size_diff * 5);
    
    RETURN score;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to update cellule status based on participants
CREATE OR REPLACE FUNCTION update_cellule_status()
RETURNS TRIGGER AS $$
DECLARE
    p_count INT;
    min_p INT;
BEGIN
    SELECT get_participant_count(NEW.cellule_id) INTO p_count;
    SELECT min_participants INTO min_p FROM cellules WHERE id = NEW.cellule_id;
    
    -- Auto-activate when minimum reached
    IF p_count >= min_p THEN
        UPDATE cellules 
        SET status = 'active', activated_at = NOW(), updated_at = NOW()
        WHERE id = NEW.cellule_id AND status = 'recruiting';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_cellule_status
AFTER INSERT OR UPDATE ON participants
FOR EACH ROW EXECUTE FUNCTION update_cellule_status();

-- Function to auto-generate matches
CREATE OR REPLACE FUNCTION generate_matches_for_cellule(cellule_uuid UUID)
RETURNS INT AS $$
DECLARE
    inserted INT := 0;
    c RECORD;
    target RECORD;
    score FLOAT;
BEGIN
    SELECT * INTO c FROM cellules WHERE id = cellule_uuid;
    
    FOR target IN 
        SELECT * FROM find_nearby_cellules(c.location, 50000, cellule_uuid)
        WHERE participant_count >= 5
    LOOP
        score := calculate_match_score(
            LEAST(cellule_uuid, target.id),
            GREATEST(cellule_uuid, target.id)
        );
        
        INSERT INTO matches (cellule_a_id, cellule_b_id, score, distance_km, common_themes)
        VALUES (
            LEAST(cellule_uuid, target.id),
            GREATEST(cellule_uuid, target.id),
            score,
            target.distance_km,
            CASE WHEN c.theme = target.theme THEN ARRAY[c.theme::TEXT] ELSE '{}' END
        )
        ON CONFLICT (cellule_a_id, cellule_b_id) 
        DO UPDATE SET score = EXCLUDED.score, updated_at = NOW();
        
        inserted := inserted + 1;
    END LOOP;
    
    RETURN inserted;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE cellules ENABLE ROW LEVEL SECURITY;
ALTER TABLE participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE ateliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE contributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE grid_nodes ENABLE ROW LEVEL SECURITY;

-- Profiles: users can see all, edit own
CREATE POLICY "Profiles are viewable by everyone" ON profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Grid nodes: public read
CREATE POLICY "Grid nodes are public" ON grid_nodes FOR SELECT USING (true);

-- Cellules: public read, creator can edit
CREATE POLICY "Cellules are viewable by everyone" ON cellules FOR SELECT USING (true);
CREATE POLICY "Users can create cellules" ON cellules FOR INSERT WITH CHECK (auth.uid() = creator_id);
CREATE POLICY "Creators can update own cellules" ON cellules FOR UPDATE USING (auth.uid() = creator_id);
CREATE POLICY "Creators can delete own cellules" ON cellules FOR DELETE USING (auth.uid() = creator_id);

-- Participants: viewable by cellule members
CREATE POLICY "Participants viewable by members" ON participants FOR SELECT USING (
    auth.uid() IN (SELECT user_id FROM participants WHERE cellule_id = participants.cellule_id)
    OR auth.uid() = (SELECT creator_id FROM cellules WHERE id = participants.cellule_id)
);
CREATE POLICY "Users can join cellules" ON participants FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can leave" ON participants FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Creators can manage participants" ON participants FOR DELETE USING (
    auth.uid() = (SELECT creator_id FROM cellules WHERE id = participants.cellule_id)
);

-- Ateliers: viewable by cellule participants
CREATE POLICY "Ateliers viewable by participants" ON ateliers FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM participants 
        WHERE cellule_id = ateliers.cellule_id AND user_id = auth.uid() AND status = 'active'
    )
);
CREATE POLICY "Creators can manage ateliers" ON ateliers FOR ALL USING (
    auth.uid() = (SELECT creator_id FROM cellules WHERE id = ateliers.cellule_id)
);

-- Contributions: viewable by atelier participants
CREATE POLICY "Contributions viewable by participants" ON contributions FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM participants p
        JOIN ateliers a ON a.cellule_id = p.cellule_id
        WHERE a.id = contributions.atelier_id AND p.user_id = auth.uid() AND p.status = 'active'
    )
);
CREATE POLICY "Participants can contribute" ON contributions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can edit own contributions" ON contributions FOR UPDATE USING (auth.uid() = user_id);

-- Matches: viewable by involved cellule creators
CREATE POLICY "Matches viewable by creators" ON matches FOR SELECT USING (
    auth.uid() IN (
        SELECT creator_id FROM cellules WHERE id IN (matches.cellule_a_id, matches.cellule_b_id)
    )
);

-- Organizations: public read
CREATE POLICY "Organizations are public" ON organizations FOR SELECT USING (true);

-- Activity log: viewable by related users
CREATE POLICY "Activity viewable by related users" ON activity_log FOR SELECT USING (
    auth.uid() = user_id OR
    auth.uid() = (SELECT creator_id FROM cellules WHERE id = activity_log.cellule_id)
);

-- ============================================================================
-- SEED DATA: Generate grid nodes for Fédération Wallonie-Bruxelles
-- ============================================================================

-- This function generates the grid (call once after setup)
CREATE OR REPLACE FUNCTION generate_fwb_grid()
RETURNS INT AS $$
DECLARE
    inserted INT := 0;
    lat FLOAT;
    lon FLOAT;
    node_id TEXT;
BEGIN
    -- Brussels (dense grid ~600m)
    FOR lat IN SELECT generate_series(50.76, 50.92, 0.006) LOOP
        FOR lon IN SELECT generate_series(4.25, 4.50, 0.006) LOOP
            node_id := 'BXL-' || ROUND(lat::numeric, 3) || '/' || ROUND(lon::numeric, 3);
            INSERT INTO grid_nodes (id, location, zone)
            VALUES (node_id, ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography, 'bxl')
            ON CONFLICT DO NOTHING;
            inserted := inserted + 1;
        END LOOP;
    END LOOP;
    
    -- Wallonia (full coverage ~2.5km)
    FOR lat IN SELECT generate_series(49.50, 50.80, 0.025) LOOP
        FOR lon IN SELECT generate_series(2.80, 6.40, 0.025) LOOP
            node_id := 'WAL-' || ROUND(lat::numeric, 3) || '/' || ROUND(lon::numeric, 3);
            INSERT INTO grid_nodes (id, location, zone)
            VALUES (node_id, ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography, 'wal')
            ON CONFLICT DO NOTHING;
            inserted := inserted + 1;
        END LOOP;
    END LOOP;
    
    RETURN inserted;
END;
$$ LANGUAGE plpgsql;

-- Run grid generation
SELECT generate_fwb_grid();

-- ============================================================================
-- VIEWS
-- ============================================================================

-- View: Cellules with participant count
CREATE OR REPLACE VIEW cellules_with_stats AS
SELECT 
    c.*,
    get_participant_count(c.id) AS participant_count,
    (SELECT COUNT(*) FROM ateliers WHERE cellule_id = c.id) AS atelier_count,
    ST_X(c.location::geometry) AS lon,
    ST_Y(c.location::geometry) AS lat
FROM cellules c;

-- View: Active matches with details
CREATE OR REPLACE VIEW matches_detailed AS
SELECT 
    m.*,
    ca.title AS cellule_a_title,
    ca.theme AS cellule_a_theme,
    get_participant_count(ca.id) AS cellule_a_participants,
    cb.title AS cellule_b_title,
    cb.theme AS cellule_b_theme,
    get_participant_count(cb.id) AS cellule_b_participants
FROM matches m
JOIN cellules ca ON m.cellule_a_id = ca.id
JOIN cellules cb ON m.cellule_b_id = cb.id;

-- ============================================================================
-- REALTIME
-- ============================================================================

-- Enable realtime for key tables
ALTER PUBLICATION supabase_realtime ADD TABLE cellules;
ALTER PUBLICATION supabase_realtime ADD TABLE participants;
ALTER PUBLICATION supabase_realtime ADD TABLE ateliers;
ALTER PUBLICATION supabase_realtime ADD TABLE contributions;
ALTER PUBLICATION supabase_realtime ADD TABLE matches;
