class AddAmyHodge < ActiveRecord::Migration[4.2]
  def change
    admins = UserRole.where(role: 'administrators').first
    admins.users = 'bess,geisler,hfrost,jdeering,lmcrae,petucket,snydman,tcramer,tonyn,jvine,amyhodge'
    admins.save
  end
end
