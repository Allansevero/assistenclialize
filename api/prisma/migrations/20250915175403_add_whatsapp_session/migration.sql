-- AlterTable
ALTER TABLE "public"."WhatsappSession" ADD COLUMN     "name" TEXT,
ADD COLUMN     "sessionData" JSONB,
ADD COLUMN     "status" TEXT NOT NULL DEFAULT 'DISCONNECTED';
