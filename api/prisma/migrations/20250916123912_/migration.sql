/*
  Warnings:

  - Made the column `assignedToId` on table `WhatsappSession` required. This step will fail if there are existing NULL values in that column.

*/
-- DropForeignKey
ALTER TABLE "public"."WhatsappSession" DROP CONSTRAINT "WhatsappSession_assignedToId_fkey";

-- AlterTable
ALTER TABLE "public"."WhatsappSession" ADD COLUMN     "profilePictureUrl" TEXT,
ALTER COLUMN "assignedToId" SET NOT NULL;

-- AddForeignKey
ALTER TABLE "public"."WhatsappSession" ADD CONSTRAINT "WhatsappSession_assignedToId_fkey" FOREIGN KEY ("assignedToId") REFERENCES "public"."User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
